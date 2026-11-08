#!/usr/bin/env bash
# Phantom read test: runs t1-<level>.sql and t2-insert.sql as two concurrent sessions,
# saves each case as a simple timeline in results/, and prints a summary.
# Scenario and explanation: docs/tests/phantom-read.md
#
# Usage: ./tests/phantom-read/run.sh   (from the repo root, with the database running)
# Takes about 35 seconds: each case waits on the DO SLEEP delays in the scripts.
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a
. ./.env
set +a

DIR=tests/phantom-read
RESULTS=$DIR/results
CONTAINER=sakila-mysql-group
PHANTOM_ID=16050   # the rental T2 inserts and commits

mysql_session() {
  docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" "$CONTAINER" \
    mysql -u"$MYSQL_USER" "$MYSQL_DATABASE" --batch -N "$@"
}

remove_phantom() {
  mysql_session -e "DELETE FROM film_rental WHERE rental_id = $PHANTOM_ID;"
}

# Merges both sessions' rows (who, step, time, value[, waited]) into one timeline,
# with times in seconds since T1 started.
timeline() {
  awk -F'\t' -v OFS='\t' '
    function secs(ts,  t) { split(substr(ts, 12), t, ":"); return t[1] * 3600 + t[2] * 60 + t[3] }
    {
      at = secs($3)
      step = $2; sub(/^T[12] /, "", step)
      if (step == "start") { start[$1] = at; print sprintf("%.6f", at), $1, "start (" $4 ")", ""; next }
      if ($5 != "" && $5 + 0 > 0.1) {
        blocked = at - $5; if (blocked < start[$1]) blocked = start[$1]
        print sprintf("%.6f", blocked), $1, "insert BLOCKED (T1 holds gap locks)", ""
        print sprintf("%.6f", at), $1, "inserted after waiting " sprintf("%.2f", $5) " s (uncommitted)", $4
        next
      }
      print sprintf("%.6f", at), $1, step, $4
    }' |
  sort -t$'\t' -k1,1n -s |
  awk -F'\t' '
    NR == 1 { t0 = $1 }
    { printf "%7.2f s   %-3s  %-44s %s\n", $1 - t0, $2, $3, $4 }'
}

mkdir -p "$RESULTS"
remove_phantom
echo "Customer 75 unreturned rentals before test: $(mysql_session -e \
  "SELECT CONCAT('COUNT=', COUNT(*), ', MAX(rental_date)=', MAX(rental_date)) FROM film_rental WHERE customer_id = 75 AND return_date IS NULL;")"

summary=()
for level in read-uncommitted read-committed repeatable-read serializable; do
  name=$(tr 'a-z-' 'A-Z ' <<< "$level")
  echo "Running $name..."

  # Baseline state: rental 16050 does not exist
  remove_phantom

  # T1 (reader) in the background, T2 (inserter) 1.5 seconds later
  t1_out=$(mktemp)
  mysql_session < "$DIR/t1-$level.sql" > "$t1_out" &
  t1=$!
  sleep 1.5
  t2_rows=$(mysql_session < "$DIR/t2-insert.sql")
  wait "$t1"
  t1_rows=$(cat "$t1_out")
  rm "$t1_out"

  read1_val=$(grep '^T1 read 1' <<< "$t1_rows" | cut -f3)
  read2_val=$(grep '^T1 read 2' <<< "$t1_rows" | cut -f3)
  t2_waited=$(grep '^T2 inserted' <<< "$t2_rows" | cut -f4)

  if [ "$read1_val" != "$read2_val" ]; then
    phantom="YES"
    verdict="PHANTOM READ: the same aggregate query returned '$read1_val' then '$read2_val' within one transaction."
  else
    phantom="no"
    verdict="NO PHANTOM: T1 saw '$read1_val' on both reads although T2 inserted and committed rental $PHANTOM_ID."
  fi
  if awk -v w="$t2_waited" 'BEGIN { exit !(w + 0 > 0.1) }'; then
    verdict="$verdict T2's insert was blocked for $t2_waited s."
  fi

  {
    echo "Phantom read test: $name"
    echo "T1 runs COUNT(*) and MAX(rental_date) over customer 75's unreturned rentals twice. T2 inserts rental $PHANTOM_ID (customer 75, not returned, rented 2006-02-25 15:30:00) and commits in between."
    echo "Scripts: t1-$level.sql + t2-insert.sql"
    echo
    printf '%7s     %-3s  %-44s %s\n' "time" "who" "step" "aggregates"
    { sed 's/^/T1\t/' <<< "$t1_rows"; sed 's/^/T2\t/' <<< "$t2_rows"; } | timeline
    echo
    echo "Result: $verdict"
  } > "$RESULTS/$level.txt"

  summary+=("$(printf '%-18s | %-46s | %-46s | %8ss | %s' "$name" "$read1_val" "$read2_val" "$t2_waited" "$phantom")")

  # Restore the original data
  remove_phantom
done

echo
echo "=================================================================================================================================="
echo "PHANTOM READ TEST SUMMARY"
echo "=================================================================================================================================="
printf '%-18s | %-46s | %-46s | %9s | %s\n' "Isolation level" "T1 Read 1" "T1 Read 2" "T2 waited" "Phantom?"
echo "-------------------+------------------------------------------------+------------------------------------------------+-----------+----------"
for row in "${summary[@]}"; do
  echo "$row"
done
echo "=================================================================================================================================="

#!/usr/bin/env bash
# Non-repeatable read test: runs t1-<level>.sql and t2-writer.sql as two concurrent sessions,
# saves each case as a simple timeline in results/, and prints a summary.
# Scenario and explanation: docs/tests/non-repeatable-read.md
#
# Usage: ./tests/non-repeatable-read/run.sh   (from the repo root, with the database running)
# Takes about 35-40 seconds: each case waits on the DO SLEEP delays in the scripts.
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a
. ./.env
set +a

DIR=tests/non-repeatable-read
RESULTS=$DIR/results
CONTAINER=sakila-mysql-group
COMMITTED_VALUE='2006-02-25 15:30:00'   # the updated return_date T2 writes and commits

mysql_session() {
  docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" "$CONTAINER" \
    mysql -u"$MYSQL_USER" "$MYSQL_DATABASE" --batch -N "$@"
}

read_value() {
  mysql_session -e "SELECT IFNULL(return_date, 'NULL') FROM film_rental WHERE rental_id = 11496;"
}

restore_original() {
  mysql_session -e "UPDATE film_rental SET return_date = NULL WHERE rental_id = 11496;"
}

# Merges both sessions' rows (step, time, value[, waited]) into one timeline,
# with times in seconds since T1 started.
timeline() {
  awk -F'\t' -v OFS='\t' '
    function secs(ts,  t) { split(substr(ts, 12), t, ":"); return t[1] * 3600 + t[2] * 60 + t[3] }
    {
      at = secs($3)
      step = $2; sub(/^T[12] /, "", step)
      if (step == "start") { start[$1] = at; print sprintf("%.6f", at), $1, "start (" $4 ")", ""; next }
      if ($5 != "" && $5 + 0 > 0) {
        blocked = at - $5; if (blocked < start[$1]) blocked = start[$1]
        print sprintf("%.6f", blocked), $1, "update BLOCKED (T1 holds shared lock)", ""
        print sprintf("%.6f", at), $1, "update commits (waited " sprintf("%.2f", $5) " s)", $4
        next
      }
      print sprintf("%.6f", at), $1, step, $4
    }' |
  sort -t$'\t' -k1,1n -s |
  awk -F'\t' '
    NR == 1 { t0 = $1 }
    { printf "%7.2f s   %-3s  %-36s %s\n", $1 - t0, $2, $3, $4 }'
}

original=$(read_value)
echo "Rental 11496 return_date before test: $original"
mkdir -p "$RESULTS"

summary=()
for level in read-uncommitted read-committed repeatable-read serializable; do
  name=$(tr 'a-z-' 'A-Z ' <<< "$level")
  echo "Running $name..."

  # Ensure baseline state: return_date = NULL
  restore_original

  # T1 (reader) in the background, T2 (writer) 1.5 seconds later
  t1_out=$(mktemp)
  mysql_session < "$DIR/t1-$level.sql" > "$t1_out" &
  t1=$!
  sleep 1.5
  t2_rows=$(mysql_session < "$DIR/t2-writer.sql")
  wait "$t1"
  t1_rows=$(cat "$t1_out")
  rm "$t1_out"

  read1_val=$(grep '^T1 read 1' <<< "$t1_rows" | cut -f3)
  read2_val=$(grep '^T1 read 2' <<< "$t1_rows" | cut -f3)
  t2_waited=$(grep '^T2 updated' <<< "$t2_rows" | cut -f4)

  if [ "$read1_val" != "$read2_val" ]; then
    nrr="YES"
    verdict="NON-REPEATABLE READ: T1 saw value change from '$read1_val' to '$read2_val' within the same transaction."
  else
    nrr="no"
    verdict="REPEATABLE READ: T1 saw '$read1_val' on both reads despite T2 committing an update."
  fi

  {
    echo "Non-repeatable read test: $name"
    echo "Rental 11496. T1 reads twice. T2 updates return_date to '$COMMITTED_VALUE' and commits in between."
    echo "Scripts: t1-$level.sql + t2-writer.sql"
    echo
    printf '%7s     %-3s  %-36s %s\n' "time" "who" "step" "return_date"
    { sed 's/^/T1\t/' <<< "$t1_rows"; sed 's/^/T2\t/' <<< "$t2_rows"; } | timeline
    echo
    echo "Result: $verdict"
  } > "$RESULTS/$level.txt"

  summary+=("$(printf '%-18s | %-12s | %-21s | %8ss | %s' "$name" "$read1_val" "$read2_val" "$t2_waited" "$nrr")")

  # Restore original NULL state after run
  restore_original
done

echo
echo "=========================================================================================="
echo "NON-REPEATABLE READ TEST SUMMARY"
echo "=========================================================================================="
printf '%-18s | %-12s | %-21s | %9s | %s\n' "Isolation level" "T1 Read 1" "T1 Read 2" "T2 waited" "Non-repeatable?"
echo "-------------------+--------------+-----------------------+-----------+-------------------"
for row in "${summary[@]}"; do
  echo "$row"
done
echo "=========================================================================================="


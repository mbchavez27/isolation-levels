#!/usr/bin/env bash
# Dirty read test: runs t1-writer.sql and each t2-<level>.sql as two concurrent sessions,
# saves each case as a simple timeline in results/, and prints a summary.
# Scenario and explanation: docs/tests/dirty-read.md
#
# Usage: ./tests/dirty-read/run.sh   (from the repo root, with the database running)
# Takes about 1 minute: each case waits on the DO SLEEP delays in the scripts.
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a
. ./.env
set +a

DIR=tests/dirty-read
RESULTS=$DIR/results
CONTAINER=sakila-mysql-group
DIRTY_VALUE='2006-02-20 10:00:00'   # the uncommitted return_date T1 writes

mysql_session() {
  docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" "$CONTAINER" \
    mysql -u"$MYSQL_USER" "$MYSQL_DATABASE" --batch -N "$@"
}

read_value() {
  mysql_session -e "SELECT IFNULL(return_date, 'NULL') FROM film_rental WHERE rental_id = 11496;"
}

# Merges both sessions' rows (step, time, value[, waited]) into one timeline,
# with times in seconds since T1 started.
timeline() {
  # 1) Convert timestamps to seconds and label rows. A read that waited on a lock
  #    becomes two rows: when it blocked and when it returned.
  awk -F'\t' -v OFS='\t' '
    function secs(ts,  t) { split(substr(ts, 12), t, ":"); return t[1] * 3600 + t[2] * 60 + t[3] }
    {
      at = secs($3)
      step = $2; sub(/^T[12] /, "", step)
      if (step == "start") { start[$1] = at; print sprintf("%.6f", at), $1, "start (" $4 ")", ""; next }
      if ($5 != "" && $5 + 0 > 0) {
        blocked = at - $5; if (blocked < start[$1]) blocked = start[$1]
        print sprintf("%.6f", blocked), $1, "read 1 BLOCKED (T1 holds row lock)", ""
        print sprintf("%.6f", at), $1, "read 1 returns (waited " sprintf("%.2f", $5) " s)", $4
        next
      }
      print sprintf("%.6f", at), $1, step, $4
    }' |
  # 2) Order by time, then print times relative to the first row (T1 start).
  sort -t$'\t' -k1,1n -s |
  awk -F'\t' '
    NR == 1 { t0 = $1 }
    { printf "%7.2f s   %-3s  %-34s %s\n", $1 - t0, $2, $3, $4 }'
}

original=$(read_value)
echo "Rental 11496 return_date before test: $original"
mkdir -p "$RESULTS"

summary=()
for level in read-uncommitted read-committed repeatable-read serializable; do
  name=$(tr 'a-z-' 'A-Z ' <<< "$level")
  echo "Running $name..."

  # T1 in the background, T2 one second later so T1's update is already pending.
  t1_out=$(mktemp)
  mysql_session < "$DIR/t1-writer.sql" > "$t1_out" &
  t1=$!
  sleep 1
  t2_rows=$(mysql_session < "$DIR/t2-$level.sql")
  wait "$t1"
  t1_rows=$(cat "$t1_out")
  rm "$t1_out"

  read1=$(grep '^T2 read 1' <<< "$t2_rows")
  seen=$(cut -f3 <<< "$read1")
  waited=$(cut -f4 <<< "$read1")
  if [ "$seen" = "$DIRTY_VALUE" ]; then
    dirty="YES"
    verdict="DIRTY READ: T2 read return_date = $seen, a change T1 rolled back."
  else
    dirty="no"
    verdict="NO DIRTY READ: T2 only saw the committed value ($seen)."
  fi

  {
    echo "Dirty read test: $name"
    echo "Rental 11496. T1 sets return_date = '$DIRTY_VALUE', holds it 10 s, then rolls back."
    echo "Scripts: t1-writer.sql + t2-$level.sql"
    echo
    printf '%7s     %-3s  %-34s %s\n' "time" "who" "step" "return_date"
    { sed 's/^/T1\t/' <<< "$t1_rows"; sed 's/^/T2\t/' <<< "$t2_rows"; } | timeline
    echo
    echo "Result: $verdict"
  } > "$RESULTS/$level.txt"

  summary+=("$(printf '%-18s | %-21s | %8ss | %s' "$name" "$seen" "$waited" "$dirty")")

  after=$(read_value)
  if [ "$after" != "$original" ]; then
    echo "ERROR: return_date is '$after' after rollback, expected '$original'" >&2
    exit 1
  fi
done

echo
printf '%-18s | %-21s | %-9s | %s\n' "Isolation level" "T2 read 1" "T2 waited" "Dirty read?"
printf '%-18s-+-%-21s-+-%-9s-+-%s\n' "------------------" "---------------------" "---------" "-----------"
printf '%s\n' "${summary[@]}"
echo
echo "Rental 11496 return_date after test: $(read_value) (T1 rolled back every run)"
echo "Timeline per case: $RESULTS/<level>.txt"

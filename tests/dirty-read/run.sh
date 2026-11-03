#!/usr/bin/env bash
# Dirty read test: runs t1-writer.sql and each t2-<level>.sql as two concurrent sessions,
# saves each case's full output to results/, and prints a summary.
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
    mysql -u"$MYSQL_USER" "$MYSQL_DATABASE" "$@"
}

read_value() {
  mysql_session --batch -N -e "SELECT IFNULL(return_date, 'NULL') FROM film_rental WHERE rental_id = 11496;"
}

original=$(read_value)
echo "Rental 11496 return_date before test: $original"
mkdir -p "$RESULTS"

summary=()
for level in read-uncommitted read-committed repeatable-read serializable; do
  echo "Running $level..."
  out=$RESULTS/$level.txt

  # T1 in the background, T2 one second later so T1's update is already pending.
  mysql_session --table < "$DIR/t1-writer.sql" > "$RESULTS/$level-t1.txt" &
  t1=$!
  sleep 1
  mysql_session --table < "$DIR/t2-$level.sql" > "$RESULTS/$level-t2.txt"
  wait "$t1"

  { echo "== T1 (t1-writer.sql) =="; cat "$RESULTS/$level-t1.txt"
    echo; echo "== T2 (t2-$level.sql) =="; cat "$RESULTS/$level-t2.txt"; } > "$out"
  rm "$RESULTS/$level-t1.txt" "$RESULTS/$level-t2.txt"

  # Pull read 1's value and wait time out of T2's table output.
  read1=$(grep 'T2 read 1' "$out" | awk -F'|' '{gsub(/^ +| +$/, "", $4); gsub(/^ +| +$/, "", $5); print $4 "|" $5}')
  seen=${read1%|*}
  waited=${read1#*|}
  if [ "$seen" = "$DIRTY_VALUE" ]; then dirty="YES"; else dirty="no"; fi
  summary+=("$(printf '%-18s | %-21s | %8ss | %s' "$(tr 'a-z-' 'A-Z ' <<< "$level")" "$seen" "$waited" "$dirty")")

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
echo "Full output per case: $RESULTS/<level>.txt"

#!/usr/bin/env bash
# Lock experiments: runs each T1/T2 pair as two concurrent sessions, takes a snapshot of the
# InnoDB locks while T2 is blocked, saves each case as a timeline in results/, prints a summary.
# Scenario and explanation: docs/tests/locks.md
#
# Usage: ./tests/locks/run.sh   (from the repo root, with the database running)
# Takes about 40 seconds: each case waits on the DO SLEEP(6) in T1.
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a
. ./.env
set +a

DIR=tests/locks
RESULTS=$DIR/results
CONTAINER=sakila-mysql-group

mysql_session() {
  docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" "$CONTAINER" \
    mysql -u"$MYSQL_USER" "$MYSQL_DATABASE" --batch -N "$@"
}

# performance_schema needs root
mysql_root() {
  docker exec -i -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" "$CONTAINER" \
    mysql -uroot --table "$@"
}

reset_data() {
  mysql_session -e "
    UPDATE film_rental SET return_date = NULL WHERE rental_id = 11496;
    UPDATE film_rental SET return_date = '2005-05-26 22:04:30' WHERE rental_id = 1;
    DELETE FROM film_rental WHERE rental_id = 16050;"
}

lock_snapshot() {
  mysql_root -e "
    SELECT l.OBJECT_NAME AS table_name, l.INDEX_NAME AS index_name, l.LOCK_TYPE AS lock_type,
           l.LOCK_MODE AS lock_mode, l.LOCK_STATUS AS lock_status, l.LOCK_DATA AS lock_data
    FROM performance_schema.data_locks l
    WHERE l.OBJECT_NAME = 'film_rental'
    ORDER BY l.ENGINE_TRANSACTION_ID, l.LOCK_TYPE DESC, l.LOCK_DATA;
    SELECT OBJECT_NAME AS table_name, LOCK_TYPE AS mdl_lock_type, LOCK_STATUS AS mdl_status
    FROM performance_schema.metadata_locks
    WHERE OBJECT_SCHEMA = '$MYSQL_DATABASE' AND OBJECT_NAME = 'film_rental';" 2>/dev/null ||
    echo "(lock snapshot unavailable)"
}

# Merges both sessions' rows (who, step, time, value, waited) into one timeline,
# with times in seconds since T1 started. A step that waited gets an extra BLOCKED line.
timeline() {
  awk -F'\t' -v OFS='\t' '
    function secs(ts,  t) { split(substr(ts, 12), t, ":"); return t[1] * 3600 + t[2] * 60 + t[3] }
    function out(time, who, step, value) { last[who] = time; print sprintf("%.6f", time), ++n, who, step, value }
    {
      at = secs($3); step = $2; sub(/^T[12] /, "", step)
      if (step == "start") { out(at, $1, "start (" $4 ")", ""); next }
      if ($5 != "" && $5 + 0 >= 0.1) {
        blocked = at - $5; if (blocked < last[$1]) blocked = last[$1]
        out(blocked, $1, step " -> BLOCKED", "")
        out(at, $1, step " done (waited " sprintf("%.2f", $5) " s)", $4)
        next
      }
      out(at, $1, step, $4)
    }' |
  sort -t$'\t' -k1,1n -k2,2n |
  awk -F'\t' 'NR == 1 { t0 = $1 } { printf "%7.2f s   %-3s  %-50s %s\n", $1 - t0, $3, $4, $5 }'
}

mkdir -p "$RESULTS"
summary=()

# id | level | T1 script | T2 script | what the case shows
cases=(
  "l1-read-uncommitted|READ UNCOMMITTED|l1-t1-writer.sql|l1-t2-reader.sql|Dirty read fixed by FOR SHARE"
  "l2-read-committed|READ COMMITTED|l2-t1-reader.sql|l2-t2-writer.sql|Non-repeatable read fixed by FOR UPDATE"
  "l3-repeatable-read|REPEATABLE READ|l3-t1-range.sql|l3-t2-insert.sql|Phantom blocked by next-key (gap) locks"
  "l4a-serializable|SERIALIZABLE|l4-t1-serializable.sql|l4-t2-writer.sql|Implicit row S-lock (only row 11496)"
  "l4b-table-lock|SERIALIZABLE + LOCK TABLES|l4-t1-table-lock.sql|l4-t2-writer.sql|Table lock (blocks every row)"
)

for c in "${cases[@]}"; do
  IFS='|' read -r id level t1_sql t2_sql desc <<< "$c"
  echo "Running $id ($desc)..."
  reset_data

  t1_out=$(mktemp)
  mysql_session < "$DIR/$t1_sql" | sed 's/^/T1\t/' > "$t1_out" &
  t1=$!
  sleep 1.5
  t2_out=$(mktemp)
  mysql_session < "$DIR/$t2_sql" | sed 's/^/T2\t/' > "$t2_out" &
  t2=$!
  sleep 1.5                     # T2 should be blocked by now
  locks=$(lock_snapshot)
  wait "$t1" "$t2"

  rows=$(cat "$t1_out" "$t2_out"); rm "$t1_out" "$t2_out"
  max_wait=$(awk -F'\t' '$5 != "" && $5 + 0 > m { m = $5 + 0 } END { printf "%.2f", m }' <<< "$rows")

  {
    echo "Lock experiment: $id ($level)"
    echo "$desc"
    echo "Scripts: $t1_sql + $t2_sql"
    echo
    printf '%7s     %-3s  %-50s %s\n' "time" "who" "step" "value"
    timeline <<< "$rows"
    echo
    echo "Locks on film_rental at ~3 s (while T2 waits):"
    echo "$locks"
  } > "$RESULTS/$id.txt"

  summary+=("$(printf '%-20s | %-27s | %-40s | %6ss' "$id" "$level" "$desc" "$max_wait")")
done

reset_data

echo
echo "=============================================================================================================="
echo "LOCK EXPERIMENTS SUMMARY"
echo "=============================================================================================================="
printf '%-20s | %-27s | %-40s | %7s\n' "Case" "Isolation level" "What it shows" "T2 wait"
echo "---------------------+-----------------------------+------------------------------------------+---------"
for row in "${summary[@]}"; do echo "$row"; done
echo "=============================================================================================================="
echo "Timelines and lock snapshots: $RESULTS/"

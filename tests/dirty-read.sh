#!/usr/bin/env bash
# Dirty read test: runs the scenario from DIRTY_READ.md at all 4 isolation levels
# using two concurrent sessions, and prints what the reader (T2) saw at each level.
#
# Usage: ./tests/dirty-read.sh   (from the repo root, with the database running)
set -euo pipefail

cd "$(dirname "$0")/.."
set -a
. ./.env
set +a

CONTAINER=sakila-mysql-group
RENTAL_ID=11496                      # HYDE DOCTOR, not yet returned
DIRTY_VALUE='2006-02-20 10:00:00'    # T1's uncommitted return_date
HOLD_SECONDS=3                       # how long T1 keeps its change uncommitted

run_sql() {
  docker exec -e MYSQL_PWD="$MYSQL_PASSWORD" "$CONTAINER" \
    mysql -u"$MYSQL_USER" "$MYSQL_DATABASE" --batch -N -e "$1"
}

read_value() {
  run_sql "SELECT IFNULL(return_date, 'NULL') FROM film_rental WHERE rental_id = $RENTAL_ID;"
}

original=$(read_value)
echo "Rental $RENTAL_ID return_date before test: $original"
echo

printf '%-18s | %-21s | %-9s | %s\n' "Isolation level" "T2 read" "T2 waited" "Dirty read?"
printf '%-18s-+-%-21s-+-%-9s-+-%s\n' "------------------" "---------------------" "---------" "-----------"

for level in "READ UNCOMMITTED" "READ COMMITTED" "REPEATABLE READ" "SERIALIZABLE"; do
  # T1: change the row, hold the change uncommitted, then roll back.
  run_sql "START TRANSACTION;
           UPDATE film_rental SET return_date = '$DIRTY_VALUE' WHERE rental_id = $RENTAL_ID;
           DO SLEEP($HOLD_SECONDS);
           ROLLBACK;" > /dev/null &
  t1=$!
  sleep 1

  # T2: read the row while T1's change is still pending, timing how long the read takes.
  result=$(run_sql "SET SESSION TRANSACTION ISOLATION LEVEL $level;
                    START TRANSACTION;
                    SET @start = SYSDATE(6);
                    SELECT IFNULL(return_date, 'NULL') INTO @seen FROM film_rental WHERE rental_id = $RENTAL_ID;
                    SELECT @seen, ROUND(TIMESTAMPDIFF(MICROSECOND, @start, SYSDATE(6)) / 1000000, 2);
                    COMMIT;")
  wait "$t1"

  seen=$(cut -f1 <<< "$result")
  waited=$(cut -f2 <<< "$result")
  if [ "$seen" = "$DIRTY_VALUE" ]; then dirty="YES"; else dirty="no"; fi
  printf '%-18s | %-21s | %8ss | %s\n' "$level" "$seen" "$waited" "$dirty"

  after=$(read_value)
  if [ "$after" != "$original" ]; then
    echo "ERROR: return_date is '$after' after rollback, expected '$original'" >&2
    exit 1
  fi
done

echo
echo "Rental $RENTAL_ID return_date after test: $(read_value) (T1 rolled back every run)"

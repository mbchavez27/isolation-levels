-- Non-repeatable read test, T1 (reader) at READ COMMITTED.
-- Read 1 happens before T2 updates; Read 2 happens after T2 commits.
-- In READ COMMITTED, each SELECT gets a new Read View, so Read 2 will see T2's committed change!

SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS isolation_level;

START TRANSACTION;

SELECT 'T1 read 1' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

DO SLEEP(6);

SELECT 'T1 read 2' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

COMMIT;


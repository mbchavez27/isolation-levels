-- Non-repeatable read test, T1 (reader) at REPEATABLE READ.
-- In REPEATABLE READ, InnoDB reuses the Read View established at Read 1.
-- Read 2 is guaranteed to return the exact same snapshot value even though T2 committed!

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS isolation_level;

START TRANSACTION;

SELECT 'T1 read 1' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

DO SLEEP(6);

SELECT 'T1 read 2' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

COMMIT;


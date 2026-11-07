-- Lock experiment L2 (READ COMMITTED + non-repeatable read), T1 (reader).
-- Read 1 is SELECT ... FOR UPDATE, which takes an exclusive (X) lock on rental 11496.
-- T2's UPDATE must wait for that lock, so Read 2 sees the same value as Read 1.

SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS value, '' AS waited_seconds;

START TRANSACTION;

SELECT 'T1 read 1 (FOR UPDATE)' AS step, SYSDATE(6) AS at_time, IFNULL(return_date, 'NULL') AS value, '' AS waited_seconds
FROM film_rental WHERE rental_id = 11496 FOR UPDATE;

DO SLEEP(6);

SELECT 'T1 read 2' AS step, SYSDATE(6) AS at_time, IFNULL(return_date, 'NULL') AS value, '' AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

COMMIT;
SELECT 'T1 committed' AS step, SYSDATE(6) AS at_time, '' AS value, '' AS waited_seconds;

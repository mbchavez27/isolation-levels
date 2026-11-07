-- Lock experiment L4a (SERIALIZABLE, implicit row locks), T1 (reader).
-- At SERIALIZABLE, InnoDB turns every plain SELECT into SELECT ... FOR SHARE, so T1 holds a
-- shared (S) lock on rental 11496 only. Other rows stay free.

SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS value, '' AS waited_seconds;

START TRANSACTION;

SELECT 'T1 read 1' AS step, SYSDATE(6) AS at_time, IFNULL(return_date, 'NULL') AS value, '' AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

DO SLEEP(6);

SELECT 'T1 read 2' AS step, SYSDATE(6) AS at_time, IFNULL(return_date, 'NULL') AS value, '' AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

COMMIT;
SELECT 'T1 committed' AS step, SYSDATE(6) AS at_time, '' AS value, '' AS waited_seconds;

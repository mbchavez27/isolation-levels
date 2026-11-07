-- Lock experiment L1 (READ UNCOMMITTED + dirty read), T1 (writer).
-- Same writer as the dirty read test: updates rental 11496, holds it uncommitted, rolls back.
-- The UPDATE takes an exclusive (X) row lock that is held until ROLLBACK.

SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS value, '' AS waited_seconds;

START TRANSACTION;

UPDATE film_rental SET return_date = '2006-02-20 10:00:00' WHERE rental_id = 11496;
SELECT 'T1 updated (uncommitted)' AS step, SYSDATE(6) AS at_time, return_date AS value, '' AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

DO SLEEP(6);

ROLLBACK;
SELECT 'T1 rolled back' AS step, SYSDATE(6) AS at_time, return_date AS value, '' AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

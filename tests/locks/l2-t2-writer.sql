-- Lock experiment L2, T2 (writer). Same update as the non-repeatable read test.
-- Blocks on T1's FOR UPDATE lock until T1 commits.

SELECT 'T2 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS value, '' AS waited_seconds;

START TRANSACTION;

SET @update_start = SYSDATE(6);
UPDATE film_rental SET return_date = '2006-02-25 15:30:00' WHERE rental_id = 11496;
SELECT 'T2 update rental 11496' AS step, SYSDATE(6) AS at_time, return_date AS value,
       ROUND(TIMESTAMPDIFF(MICROSECOND, @update_start, SYSDATE(6)) / 1000000, 2) AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

COMMIT;

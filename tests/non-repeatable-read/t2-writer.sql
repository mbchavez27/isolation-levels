-- Non-repeatable read test, T2 (writer).
-- Starts 1-2 seconds after T1.
-- Updates return_date for rental 11496 and COMMITS immediately.
-- Under SERIALIZABLE, this UPDATE will block until T1 commits!

SELECT 'T2 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS isolation_level;

START TRANSACTION;

SET @update_start = SYSDATE(6);
UPDATE film_rental SET return_date = '2006-02-25 15:30:00' WHERE rental_id = 11496;

SELECT 'T2 updated & committed' AS step, SYSDATE(6) AS at_time, return_date,
       ROUND(TIMESTAMPDIFF(MICROSECOND, @update_start, SYSDATE(6)) / 1000000, 2) AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

COMMIT;


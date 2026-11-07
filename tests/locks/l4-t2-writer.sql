-- Lock experiment L4, T2 (writer). Same script for L4a and L4b.
-- Update 1 touches an UNRELATED row (rental 1). Update 2 touches the row T1 is reading (11496).
-- Row locks (L4a) only block update 2. A table lock (L4b) blocks update 1 too.

SELECT 'T2 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS value, '' AS waited_seconds;

START TRANSACTION;

SET @update_start = SYSDATE(6);
UPDATE film_rental SET return_date = '2006-02-25 15:30:00' WHERE rental_id = 1;
SELECT 'T2 update rental 1 (other row)' AS step, SYSDATE(6) AS at_time, 'updated' AS value,
       ROUND(TIMESTAMPDIFF(MICROSECOND, @update_start, SYSDATE(6)) / 1000000, 2) AS waited_seconds;

SET @update_start = SYSDATE(6);
UPDATE film_rental SET return_date = '2006-02-25 15:30:00' WHERE rental_id = 11496;
SELECT 'T2 update rental 11496' AS step, SYSDATE(6) AS at_time, 'updated' AS value,
       ROUND(TIMESTAMPDIFF(MICROSECOND, @update_start, SYSDATE(6)) / 1000000, 2) AS waited_seconds;

COMMIT;

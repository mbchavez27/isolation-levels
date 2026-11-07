-- Lock experiment L1 (READ UNCOMMITTED + dirty read), T2 (reader).
-- Read 1 is a plain SELECT: at READ UNCOMMITTED it returns T1's uncommitted value (dirty read).
-- Read 2 is a locking read (FOR SHARE): it needs a shared (S) lock, which conflicts with T1's
-- X lock, so it waits until T1 rolls back and then returns the committed value.

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT 'T2 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS value, '' AS waited_seconds;

START TRANSACTION;

SELECT 'T2 read 1 (plain)' AS step, SYSDATE(6) AS at_time, return_date AS value, '' AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

SET @read_start = SYSDATE(6);
SELECT return_date INTO @locked_value FROM film_rental WHERE rental_id = 11496 FOR SHARE;
SELECT 'T2 read 2 (FOR SHARE)' AS step, SYSDATE(6) AS at_time, IFNULL(@locked_value, 'NULL') AS value,
       ROUND(TIMESTAMPDIFF(MICROSECOND, @read_start, SYSDATE(6)) / 1000000, 2) AS waited_seconds;

COMMIT;

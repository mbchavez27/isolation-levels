-- Dirty read test, T2 (reader) at SERIALIZABLE.
-- Run while t1-writer.sql is holding its uncommitted change.
-- Read 1 happens while T1's change is pending; read 2 happens after T1 rolls back.

SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT 'T2 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS isolation_level;

START TRANSACTION;

-- Read 1: T1 has updated the row but not committed.
SET @read_start = SYSDATE(6);
SELECT 'T2 read 1 (T1 pending)' AS step, SYSDATE(6) AS at_time, return_date,
       ROUND(TIMESTAMPDIFF(MICROSECOND, @read_start, SYSDATE(6)) / 1000000, 2) AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

-- Wait until T1 has rolled back.
DO SLEEP(10);

-- Read 2: T1 has rolled back, so the committed value is NULL again.
SELECT 'T2 read 2 (T1 rolled back)' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

COMMIT;

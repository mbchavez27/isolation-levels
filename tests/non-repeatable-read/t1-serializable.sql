-- Non-repeatable read test, T1 (reader) at SERIALIZABLE.
-- In SERIALIZABLE, plain SELECT is converted to SELECT ... FOR SHARE, holding a Shared Lock (S).
-- When T2 attempts to UPDATE this row, T2 BLOCKS waiting for T1 to commit!

SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS isolation_level;

START TRANSACTION;

-- Read 1 acquires Shared Lock (S) on row 11496
SELECT 'T1 read 1' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

-- Sleep while holding the shared lock
DO SLEEP(6);

-- Read 2 while still holding the shared lock
SELECT 'T1 read 2' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

COMMIT; -- Releases the shared lock, allowing blocked T2 to proceed


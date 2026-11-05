-- Non-repeatable read test, T1 (reader) at READ UNCOMMITTED.
-- Starts first, reads rental 11496 (Read 1), sleeps 6 seconds while T2 updates and commits,
-- then reads rental 11496 again (Read 2).

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS isolation_level;

START TRANSACTION;

-- Read 1: Initial read before T2 updates
SELECT 'T1 read 1' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

-- Sleep to allow T2 to execute and commit its update
DO SLEEP(6);

-- Read 2: Second read after T2 has committed
SELECT 'T1 read 2' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

COMMIT;


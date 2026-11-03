-- Dirty read test, T1 (writer). Same script for all 4 isolation levels.
-- Marks rental 11496 as returned, holds the change uncommitted, then rolls back.
-- Start this first, then start the T2 script for the level you're testing within 10 seconds.

SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS isolation_level;

START TRANSACTION;

UPDATE film_rental SET return_date = '2006-02-20 10:00:00' WHERE rental_id = 11496;
SELECT 'T1 updated (uncommitted)' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

-- Keep the change uncommitted so T2 can try to read it.
DO SLEEP(10);

ROLLBACK;
SELECT 'T1 rolled back' AS step, SYSDATE(6) AS at_time, return_date
FROM film_rental WHERE rental_id = 11496;

-- Phantom read test, T1 (reader) at READ UNCOMMITTED.
-- Plain SELECTs read the latest version of each row, so Read 2 counts T2's new row (phantom).
-- Follows the slide 13 template: SET ISOLATION LEVEL, START TRANSACTION, SELECT, <sleep>, SELECT, END.
-- Like slide 18 (Avg/Max over Student), T1 runs aggregate functions over a set of rows:
-- the number of customer 75's unreturned rentals and the latest rental date among them.
-- T2 inserts a new matching row and commits while T1 sleeps.

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS isolation_level;

START TRANSACTION;

-- Read 1: aggregates before T2 inserts
SELECT 'T1 read 1' AS step, SYSDATE(6) AS at_time,
       CONCAT('COUNT=', COUNT(*), ', MAX(rental_date)=', IFNULL(MAX(rental_date), 'NULL')) AS aggregates
FROM film_rental WHERE customer_id = 75 AND return_date IS NULL;

-- <sleep>: T2 inserts and commits a new matching row meanwhile
DO SLEEP(6);

-- Read 2: the same aggregates after T2 has committed
SELECT 'T1 read 2' AS step, SYSDATE(6) AS at_time,
       CONCAT('COUNT=', COUNT(*), ', MAX(rental_date)=', IFNULL(MAX(rental_date), 'NULL')) AS aggregates
FROM film_rental WHERE customer_id = 75 AND return_date IS NULL;

COMMIT; -- END TRANSACTION
SELECT 'T1 committed' AS step, SYSDATE(6) AS at_time, '' AS aggregates;

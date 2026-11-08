-- Phantom read test, T2 (inserter). Same script for all 4 cases.
-- Follows the slide 13 template: SET ISOLATION LEVEL, START TRANSACTION, write, <sleep>, COMMIT.
-- Like slide 18 (Insert Into Student), T2 inserts a new row that matches T1's query:
-- an unreturned rental (16050) for customer 75, dated later than the customer's other rentals.
-- Starts 1.5 seconds after T1. Under SERIALIZABLE, the INSERT blocks on T1's gap locks.

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ; -- MySQL's default level (slide 21)
SELECT 'T2 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS isolation_level;

START TRANSACTION;

SET @insert_start = SYSDATE(6);
INSERT INTO film_rental (rental_id, title, customer_id, rental_date, return_date)
VALUES (16050, 'ACADEMY DINOSAUR', 75, '2006-02-25 15:30:00', NULL);
SELECT 'T2 inserted (uncommitted)' AS step, SYSDATE(6) AS at_time, 'rental 16050' AS aggregates,
       ROUND(TIMESTAMPDIFF(MICROSECOND, @insert_start, SYSDATE(6)) / 1000000, 2) AS waited_seconds;

-- <sleep> before committing, as in the slide template
DO SLEEP(2);

COMMIT;
SELECT 'T2 committed' AS step, SYSDATE(6) AS at_time, 'rental 16050' AS aggregates;

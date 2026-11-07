-- Lock experiment L3, T2 (inserter).
-- Inserts a new rental (16050) inside T1's range. Blocks on T1's gap lock until T1 commits.

SELECT 'T2 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS value, '' AS waited_seconds;

START TRANSACTION;

SET @insert_start = SYSDATE(6);
INSERT INTO film_rental (rental_id, title, customer_id, rental_date, return_date)
VALUES (16050, 'HYDE DOCTOR', 130, '2006-02-25 15:30:00', NULL);
SELECT 'T2 insert rental 16050' AS step, SYSDATE(6) AS at_time, 'inserted' AS value,
       ROUND(TIMESTAMPDIFF(MICROSECOND, @insert_start, SYSDATE(6)) / 1000000, 2) AS waited_seconds;

COMMIT;

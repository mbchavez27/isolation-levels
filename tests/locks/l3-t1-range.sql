-- Lock experiment L3 (REPEATABLE READ + phantom read), T1 (range reader).
-- Counts the newest rentals (rental_id >= 16040) twice with a locking read.
-- FOR UPDATE takes next-key locks (row + gap locks) on the scanned range, including the gap
-- after the last row, so T2 cannot insert a new row into the range until T1 commits.
-- Without the lock, a locking read / UPDATE in T1 would see T2's new row (a phantom).

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS value, '' AS waited_seconds;

START TRANSACTION;

SELECT COUNT(*) INTO @count1 FROM film_rental WHERE rental_id >= 16040 FOR UPDATE;
SELECT 'T1 count 1 (FOR UPDATE)' AS step, SYSDATE(6) AS at_time, @count1 AS value, '' AS waited_seconds;

DO SLEEP(6);

SELECT COUNT(*) INTO @count2 FROM film_rental WHERE rental_id >= 16040 FOR UPDATE;
SELECT 'T1 count 2 (FOR UPDATE)' AS step, SYSDATE(6) AS at_time, @count2 AS value, '' AS waited_seconds;

COMMIT;
SELECT 'T1 committed' AS step, SYSDATE(6) AS at_time, '' AS value, '' AS waited_seconds;

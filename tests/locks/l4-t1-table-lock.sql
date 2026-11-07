-- Lock experiment L4b (explicit table lock), T1 (reader).
-- LOCK TABLES ... READ locks the WHOLE film_rental table: nobody else can write ANY row
-- until UNLOCK TABLES. Same reads as L4a, so the only difference is lock granularity.

SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT 'T1 start' AS step, SYSDATE(6) AS at_time, @@transaction_isolation AS value, '' AS waited_seconds;

LOCK TABLES film_rental READ;

SELECT 'T1 read 1 (table locked)' AS step, SYSDATE(6) AS at_time, IFNULL(return_date, 'NULL') AS value, '' AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

DO SLEEP(6);

SELECT 'T1 read 2' AS step, SYSDATE(6) AS at_time, IFNULL(return_date, 'NULL') AS value, '' AS waited_seconds
FROM film_rental WHERE rental_id = 11496;

UNLOCK TABLES;
SELECT 'T1 unlocked' AS step, SYSDATE(6) AS at_time, '' AS value, '' AS waited_seconds;

# Dirty Read Test

A **dirty read** happens when a transaction reads data that another transaction has changed but not yet committed. If the writer then rolls back, the reader has seen a value that never officially existed.

This test runs the same scenario at each of the 4 isolation levels against the [`film_rental`](FILM_RENTAL.md) table.

## Scenario

Rental `11496` (HYDE DOCTOR) has not been returned yet (`return_date` is `NULL`).

- **T1** (a clerk) marks the rental as returned, but doesn't commit, then rolls back.
- **T2** checks whether the rental was returned while T1's change is still pending.

## Run automatically

[`tests/dirty-read.sh`](tests/dirty-read.sh) runs both sessions at all 4 levels and prints the results. It is safe to rerun, since T1 always rolls back. Run it from the repo root with the database up (macOS, Linux, or Git Bash/WSL on Windows):

```sh
./tests/dirty-read.sh
```

```text
Isolation level    | T2 read               | T2 waited | Dirty read?
-------------------+-----------------------+-----------+------------
READ UNCOMMITTED   | 2006-02-20 10:00:00   |     0.00s | YES
READ COMMITTED     | NULL                  |     0.00s | no
REPEATABLE READ    | NULL                  |     0.00s | no
SERIALIZABLE       | NULL                  |     1.95s | no
```

`T2 waited` is how long T2's `SELECT` took. At SERIALIZABLE it waits until T1 rolls back.

## Setup (manual)

To run the test by hand instead, open two terminals and connect to MySQL in each one (enter `MYSQL_PASSWORD` from `.env` when prompted):

```sh
docker exec -it sakila-mysql-group mysql -u sakila -p sakila
```

Terminal 1 is **T1** and terminal 2 is **T2**. Before each run, confirm the starting value:

```sql
SELECT * FROM film_rental WHERE rental_id = 11496;
-- return_date = NULL
```

## Steps

Run these in order, switching terminals as shown. Repeat once for each isolation level, changing only the level in step 1.

| Step | T1 (writer) | T2 (reader) |
| --- | --- | --- |
| 1 |  | `SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;` |
| 2 | `START TRANSACTION;` | `START TRANSACTION;` |
| 3 | `UPDATE film_rental SET return_date = '2006-02-20 10:00:00' WHERE rental_id = 11496;` |  |
| 4 |  | `SELECT * FROM film_rental WHERE rental_id = 11496;` |
| 5 | `ROLLBACK;` |  |
| 6 |  | `SELECT * FROM film_rental WHERE rental_id = 11496;` |
| 7 |  | `COMMIT;` |

For the other runs, replace `READ UNCOMMITTED` in step 1 with `READ COMMITTED`, `REPEATABLE READ`, or `SERIALIZABLE`. Check the active level with `SELECT @@transaction_isolation;`.

Only T2's isolation level matters here, since T2 is the one reading. T1 can stay on the default (`REPEATABLE READ`).

## Results

| Isolation level | T2 sees in step 4 | Behavior | Dirty read? |
| --- | --- | --- | --- |
| READ UNCOMMITTED | `2006-02-20 10:00:00` | Reads T1's uncommitted change right away | **Yes** |
| READ COMMITTED | `NULL` | Reads the last committed value right away | No |
| REPEATABLE READ | `NULL` | Reads the last committed value right away | No |
| SERIALIZABLE | `NULL` | **Blocks** at step 4 until T1 finishes (step 5), then returns the committed value | No |

In every run, step 6 shows `return_date = NULL`, because T1's change was rolled back.

### Why

- **READ UNCOMMITTED** reads the newest version of the row, including changes that haven't been committed. Under READ UNCOMMITTED, T2 reported a return that never happened.
- **READ COMMITTED** and **REPEATABLE READ** use consistent (non-locking) reads. InnoDB rebuilds the last committed version of the row from the undo log, so T2 never sees T1's pending change and doesn't wait.
- **SERIALIZABLE** turns a plain `SELECT` inside a transaction into `SELECT ... FOR SHARE`. That needs a shared lock on the row, which conflicts with the exclusive lock T1 took when it updated the row. T2 waits until T1 commits or rolls back.

## Notes

- **SERIALIZABLE wait:** in step 4, T2's terminal hangs with no output. That is the expected result, not a freeze. Run step 5 in T1 and T2's query finishes.
- **Lock timeout:** if T2 waits longer than 50 seconds (`innodb_lock_wait_timeout`), T2 fails with `ERROR 1205 (HY000): Lock wait timeout exceeded`. Rerun from step 2 if that happens.
- **Explicit transaction:** keep `START TRANSACTION` in T2. Without it, `autocommit` makes each `SELECT` its own transaction, and SERIALIZABLE reads it without locking, so the block doesn't happen.

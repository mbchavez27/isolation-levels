# Dirty Read Test

A **dirty read** happens when a transaction reads data that another transaction has changed but not yet committed. If the writer then rolls back, the reader has seen a value that never officially existed.

This test runs the same scenario at each of the 4 isolation levels against the [`film_rental`](../database/film-rental.md) table.

## Scenario

Rental `11496` (HYDE DOCTOR) has not been returned yet (`return_date` is `NULL`).

- **T1** (a clerk) marks the rental as returned, holds the change uncommitted for 10 seconds (`DO SLEEP(10)`), then rolls back.
- **T2** reads the rental twice: once while T1's change is pending, and once after T1 rolls back.

## Scripts

All in [`tests/dirty-read/`](../../tests/dirty-read/):

| File | Session | Purpose |
| --- | --- | --- |
| `t1-writer.sql` | T1 | Updates `return_date`, sleeps 10 s, rolls back. Same for every level. |
| `t2-read-uncommitted.sql` | T2 | Reader at READ UNCOMMITTED |
| `t2-read-committed.sql` | T2 | Reader at READ COMMITTED |
| `t2-repeatable-read.sql` | T2 | Reader at REPEATABLE READ |
| `t2-serializable.sql` | T2 | Reader at SERIALIZABLE |
| `run.sh` | both | Runs all 4 cases and saves each one as a timeline in `results/` |

Each step prints a label, a `SYSDATE(6)` timestamp, and the current `return_date`, so the output shows the order the two sessions ran in.

Data is left unchanged after every run because T1 always rolls back, so the scripts are safe to rerun.

## Run all 4 cases

From the repo root, with the database up (macOS, Linux, or Git Bash/WSL on Windows). It takes about 1 minute:

```sh
./tests/dirty-read/run.sh
```

```text
Isolation level    | T2 read 1             | T2 waited | Dirty read?
-------------------+-----------------------+-----------+------------
READ UNCOMMITTED   | 2006-02-20 10:00:00   |     0.00s | YES
READ COMMITTED     | NULL                  |     0.00s | no
REPEATABLE READ    | NULL                  |     0.00s | no
SERIALIZABLE       | NULL                  |     8.96s | no
```

Each case is saved as a simple timeline of both sessions in `tests/dirty-read/results/<level>.txt`, ending with the result. For example, `serializable.txt`:

```text
   time     who  step                               return_date
   0.00 s   T1   start (REPEATABLE-READ)
   0.00 s   T1   updated (uncommitted)              2006-02-20 10:00:00
   1.04 s   T2   start (SERIALIZABLE)
   1.04 s   T2   read 1 BLOCKED (T1 holds row lock)
  10.00 s   T1   rolling back
  10.00 s   T2   read 1 returns (waited 8.96 s)     NULL
  10.00 s   T1   rolled back                        NULL
  20.00 s   T2   read 2 (T1 rolled back)            NULL

Result: NO DIRTY READ: T2 only saw the committed value (NULL).
```

## Run one case by hand

Open two terminals in the repo root and load `.env` in each, so the password is passed to MySQL:

```sh
set -a; . ./.env; set +a
```

Then run one script per terminal:

```sh
# Terminal 1 (T1): start this first
docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" sakila-mysql-group mysql -u sakila sakila --table < tests/dirty-read/t1-writer.sql

# Terminal 2 (T2): start within 10 seconds, picking the level to test
docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" sakila-mysql-group mysql -u sakila sakila --table < tests/dirty-read/t2-read-uncommitted.sql
```

## Results

Times are seconds after T1 starts. Values are what each session saw in the actual run.

### Case 1: READ UNCOMMITTED, dirty read occurs

| T1 (writer) | T2 (reader, READ UNCOMMITTED) |
| --- | --- |
| 0 s: `START TRANSACTION` | |
| 0 s: `UPDATE ... SET return_date = '2006-02-20 10:00:00'` (uncommitted) | |
| `DO SLEEP(10)` | 1 s: `START TRANSACTION` |
| | 1 s: read 1 returns **`2006-02-20 10:00:00`** (T1's uncommitted value) |
| 10 s: `ROLLBACK` | `DO SLEEP(10)` |
| | 11 s: read 2 returns `NULL` |

T2 saw a return that was rolled back and never happened. **Dirty read: yes.**

### Case 2: READ COMMITTED, no dirty read

| T1 (writer) | T2 (reader, READ COMMITTED) |
| --- | --- |
| 0 s: `START TRANSACTION` | |
| 0 s: `UPDATE ... SET return_date = '2006-02-20 10:00:00'` (uncommitted) | |
| `DO SLEEP(10)` | 1 s: `START TRANSACTION` |
| | 1 s: read 1 returns `NULL` immediately |
| 10 s: `ROLLBACK` | `DO SLEEP(10)` |
| | 11 s: read 2 returns `NULL` |

**Dirty read: no.**

### Case 3: REPEATABLE READ, no dirty read

| T1 (writer) | T2 (reader, REPEATABLE READ) |
| --- | --- |
| 0 s: `START TRANSACTION` | |
| 0 s: `UPDATE ... SET return_date = '2006-02-20 10:00:00'` (uncommitted) | |
| `DO SLEEP(10)` | 1 s: `START TRANSACTION` |
| | 1 s: read 1 returns `NULL` immediately |
| 10 s: `ROLLBACK` | `DO SLEEP(10)` |
| | 11 s: read 2 returns `NULL` |

**Dirty read: no.**

### Case 4: SERIALIZABLE, no dirty read (T2 blocks)

| T1 (writer) | T2 (reader, SERIALIZABLE) |
| --- | --- |
| 0 s: `START TRANSACTION` | |
| 0 s: `UPDATE ... SET return_date = '2006-02-20 10:00:00'` (uncommitted) | |
| `DO SLEEP(10)` | 1 s: `START TRANSACTION` |
| | 1 s: read 1 **blocks**, waiting for T1's row lock |
| 10 s: `ROLLBACK` (releases the lock) | 10 s: read 1 returns `NULL` after waiting 8.96 s |
| | `DO SLEEP(10)` |
| | 20 s: read 2 returns `NULL` |

**Dirty read: no.** The price is the 8.96-second wait.

### Summary

| Isolation level | T2 read 1 | Waited | Dirty read? |
| --- | --- | ---: | --- |
| READ UNCOMMITTED | `2006-02-20 10:00:00` | 0.00 s | **Yes** |
| READ COMMITTED | `NULL` | 0.00 s | No |
| REPEATABLE READ | `NULL` | 0.00 s | No |
| SERIALIZABLE | `NULL` | 8.96 s | No |

### Why

- **READ UNCOMMITTED** reads the newest version of the row, including changes that haven't been committed. Nothing protects T2 from T1's pending change.
- **READ COMMITTED** and **REPEATABLE READ** use consistent (non-locking) reads. InnoDB rebuilds the last committed version of the row from the undo log, so T2 never sees T1's pending change and doesn't wait.
- **SERIALIZABLE** turns a plain `SELECT` inside a transaction into `SELECT ... FOR SHARE`. That needs a shared lock on the row, which conflicts with the exclusive lock T1 took when it updated the row. T2 waits until T1 rolls back.

## Notes

- **SERIALIZABLE wait:** T2's terminal hangs with no output at read 1. That is the expected result, not a freeze. It finishes when T1 rolls back.
- **Lock timeout:** if T2 waits longer than 50 seconds (`innodb_lock_wait_timeout`), it fails with `ERROR 1205 (HY000): Lock wait timeout exceeded`. T1 only holds its change for 10 seconds, so this won't happen with these scripts.
- **Explicit transaction:** the T2 scripts use `START TRANSACTION`. Without it, `autocommit` makes each `SELECT` its own transaction, and SERIALIZABLE reads it without locking, so the block doesn't happen.
- **Reader's level matters:** a dirty read depends on T2's isolation level, not T1's. T1 stays on the default level, `REPEATABLE READ`, in every case.

# Non-Repeatable Read Test

A **non-repeatable read** (also known as a *fuzzy read*) occurs when a transaction reads the same row twice within its execution boundary and observes different values, because another concurrent transaction modified and **committed** changes to that row in between the two reads.

This test executes the non-repeatable read scenario across all 4 standard isolation levels against the [`film_rental`](../database/film-rental.md) table.

---

## Scenario

Rental `11496` (*HYDE DOCTOR*) has not yet been returned (`return_date` is `NULL`).

* **T1 (Auditor / Reader)** starts a transaction and reads the rental's `return_date` (**Read 1**). It then pauses for 6 seconds (`DO SLEEP(6)`).
* **T2 (Clerk / Writer)** starts concurrently, updates `return_date = '2006-02-25 15:30:00'`, and **successfully commits** while T1 is paused.
* **T1** wakes up and reads the exact same row again (**Read 2**), then commits.

---

## Scripts

All located in [`tests/non-repeatable-read/`](../../tests/non-repeatable-read/):

| File | Session | Isolation Level | Purpose |
| :--- | :---: | :--- | :--- |
| `t1-read-uncommitted.sql` | T1 | READ UNCOMMITTED | Reader performing Read 1, sleep 6 s, Read 2 |
| `t1-read-committed.sql` | T1 | READ COMMITTED | Reader performing Read 1, sleep 6 s, Read 2 |
| `t1-repeatable-read.sql` | T1 | REPEATABLE READ | Reader performing Read 1, sleep 6 s, Read 2 |
| `t1-serializable.sql` | T1 | SERIALIZABLE | Reader acquiring Shared Lock ($S$), sleep 6 s, Read 2 |
| `t2-writer.sql` | T2 | REPEATABLE READ | Writer updating row and committing immediately |
| `run.sh` | Both | Automated | Orchestrates both sessions, calculates timelines, and restores `return_date = NULL` |

---

## Run All 4 Cases

From the repository root (with the MySQL container running):

```sh
./tests/non-repeatable-read/run.sh
```

### Benchmark Summary

```text
==========================================================================================
NON-REPEATABLE READ TEST SUMMARY
==========================================================================================
Isolation level    | T1 Read 1    | T1 Read 2             | T2 waited | Non-repeatable?
-------------------+--------------+-----------------------+-----------+-------------------
READ UNCOMMITTED   | NULL         | 2006-02-25 15:30:00   |     0.00s | YES
READ COMMITTED     | NULL         | 2006-02-25 15:30:00   |     0.00s | YES
REPEATABLE READ    | NULL         | NULL                  |     0.00s | no
SERIALIZABLE       | NULL         | NULL                  |     4.50s | no
==========================================================================================
```

---

## Two-Column Interleaved Timelines (For Technical Report)

### Case 1: READ UNCOMMITTED (Non-Repeatable Read Allowed)

| Timestamp ($t$) | T1 (Reader @ READ UNCOMMITTED) | T2 (Writer) | Observed Value / Remarks |
| :---: | :--- | :--- | :--- |
| $t_1 = 0.00\,\text{s}$ | `START TRANSACTION;` | | T1 begins transaction |
| $t_2 = 0.00\,\text{s}$ | `SELECT return_date ...;` | | **Read 1: returns `NULL`** |
| $t_3 = 0.00\,\text{s}$ | `DO SLEEP(6);` | | T1 pauses |
| $t_4 = 1.50\,\text{s}$ | | `START TRANSACTION;` | T2 begins transaction |
| $t_5 = 1.51\,\text{s}$ | | `UPDATE ... SET return_date = '2006-02-25 15:30:00';`<br/>`COMMIT;` | T2 modifies row and commits |
| $t_6 = 6.00\,\text{s}$ | `SELECT return_date ...;` | | **Read 2: returns `2006-02-25 15:30:00`** |
| $t_7 = 6.00\,\text{s}$ | `COMMIT;` | | T1 completes |

* **Verdict**: **NON-REPEATABLE READ: YES.** The value mutated within T1's transaction boundary.

---

### Case 2: READ COMMITTED (Non-Repeatable Read Allowed)

| Timestamp ($t$) | T1 (Reader @ READ COMMITTED) | T2 (Writer) | Observed Value / Remarks |
| :---: | :--- | :--- | :--- |
| $t_1 = 0.00\,\text{s}$ | `START TRANSACTION;` | | T1 begins transaction |
| $t_2 = 0.00\,\text{s}$ | `SELECT return_date ...;` | | **Read 1: returns `NULL`** (Read View 1 created) |
| $t_3 = 0.00\,\text{s}$ | `DO SLEEP(6);` | | T1 pauses |
| $t_4 = 1.50\,\text{s}$ | | `START TRANSACTION;` | T2 begins transaction |
| $t_5 = 1.51\,\text{s}$ | | `UPDATE ... SET return_date = '2006-02-25 15:30:00';`<br/>`COMMIT;` | T2 modifies row and commits |
| $t_6 = 6.00\,\text{s}$ | `SELECT return_date ...;` | | **Read 2: returns `2006-02-25 15:30:00`** (Read View 2 created) |
| $t_7 = 6.00\,\text{s}$ | `COMMIT;` | | T1 completes |

* **Verdict**: **NON-REPEATABLE READ: YES.** Under READ COMMITTED, each individual `SELECT` allocates a brand-new Read View, seeing T2's committed changes.

---

### Case 3: REPEATABLE READ (Non-Repeatable Read Prevented via MVCC Snapshot)

| Timestamp ($t$) | T1 (Reader @ REPEATABLE READ) | T2 (Writer) | Observed Value / Remarks |
| :---: | :--- | :--- | :--- |
| $t_1 = 0.00\,\text{s}$ | `START TRANSACTION;` | | T1 begins transaction |
| $t_2 = 0.00\,\text{s}$ | `SELECT return_date ...;` | | **Read 1: returns `NULL`** (Transaction Read View established) |
| $t_3 = 0.00\,\text{s}$ | `DO SLEEP(6);` | | T1 pauses |
| $t_4 = 1.50\,\text{s}$ | | `START TRANSACTION;` | T2 begins transaction |
| $t_5 = 1.51\,\text{s}$ | | `UPDATE ... SET return_date = '2006-02-25 15:30:00';`<br/>`COMMIT;` | T2 modifies row and commits |
| $t_6 = 6.00\,\text{s}$ | `SELECT return_date ...;` | | **Read 2: STILL returns `NULL`** (Read View reused!) |
| $t_7 = 6.00\,\text{s}$ | `COMMIT;` | | T1 completes |

* **Verdict**: **NON-REPEATABLE READ: NO (PREVENTED).** T1 reads the exact same committed snapshot established at Read 1. T2's commit is invisible to T1's snapshot.

---

### Case 4: SERIALIZABLE (Non-Repeatable Read Prevented via Lock Contention)

| Timestamp ($t$) | T1 (Reader @ SERIALIZABLE) | T2 (Writer) | Observed Value / Remarks |
| :---: | :--- | :--- | :--- |
| $t_1 = 0.00\,\text{s}$ | `START TRANSACTION;` | | T1 begins transaction |
| $t_2 = 0.00\,\text{s}$ | `SELECT return_date ...;` | | **Read 1: returns `NULL`** (Acquires Shared Lock $S$) |
| $t_3 = 0.00\,\text{s}$ | `DO SLEEP(6);` | | T1 holds $S$-lock and pauses |
| $t_4 = 1.50\,\text{s}$ | | `START TRANSACTION;` | T2 begins transaction |
| $t_5 = 1.50\,\text{s}$ | | `UPDATE ... SET return_date = '2006-02-25 15:30:00';` | **T2 BLOCKS!** Exclusive Lock ($X$) conflicts with T1's $S$-lock |
| $t_6 = 6.00\,\text{s}$ | `SELECT return_date ...;` | | **Read 2: returns `NULL`** |
| $t_7 = 6.00\,\text{s}$ | `COMMIT;` | | T1 commits $\to$ Releases $S$-lock |
| $t_8 = 6.00\,\text{s}$ | | `COMMIT;` (after waiting 4.50 s) | T2 acquires $X$-lock, executes update, and commits |

* **Verdict**: **NON-REPEATABLE READ: NO (PREVENTED).** T2 was physically prevented from modifying the row while T1 was active, incurring a 4.50-second wait penalty.

---

## Technical Analysis & Storage Engine Mechanics

1. **Why READ COMMITTED allows Non-Repeatable Reads**:
   * Under `READ COMMITTED`, InnoDB builds a **fresh Read View at the start of each individual statement**. When T2 commits at $t = 1.51\,\text{s}$, its transaction ID transitions from active to committed. When T1 executes Read 2 at $t = 6.00\,\text{s}$, its new Read View recognizes T2 as committed and reads T2's new value.
2. **Why REPEATABLE READ eliminates Non-Repeatable Reads**:
   * Under `REPEATABLE READ`, InnoDB creates a **single Read View at the time of the first read** ($t = 0.00\,\text{s}$) and preserves it across all subsequent queries until `COMMIT` or `ROLLBACK`. Even though T2 committed at $t = 1.51\,\text{s}$, T2's transaction ID is marked as greater than T1's snapshot boundary. InnoDB automatically traverses the Undo Log chain back to the pre-image (`NULL`), guaranteeing deterministic, repeatable reads without taking locks!
3. **Why SERIALIZABLE blocks writers**:
   * In `SERIALIZABLE`, consistent non-locking reads are disabled. Plain `SELECT` statements are converted into locking reads (`LOCK IN SHARE MODE` / `FOR SHARE`), granting T1 a Shared Lock ($S$). Because writes require an Exclusive Lock ($X$), T2 is suspended in the lock table until T1 releases its $S$-lock at transaction termination.


# Lock Experiments

The baseline tests show which read anomalies each isolation level allows. These experiments show how **locks** fix them, and what that costs in waiting time. There's one case per isolation level, plus a fifth case that compares row locks with an explicit table lock.

All cases use the [`film_rental`](../database/film-rental.md) table and the same rows as the other tests (rental `11496`, *HYDE DOCTOR*, `return_date = NULL`).

---

## Cases

| Case | Isolation level | Anomaly at this level | Lock used | Effect |
| :--- | :--- | :--- | :--- | :--- |
| L1 | READ UNCOMMITTED | Dirty read | `SELECT ... FOR SHARE` (row S lock) | Reader waits for the writer to finish, reads only committed data |
| L2 | READ COMMITTED | Non-repeatable read | `SELECT ... FOR UPDATE` (row X lock) | Writer waits, so the second read matches the first |
| L3 | REPEATABLE READ | Phantom read (locking reads) | `SELECT ... WHERE rental_id >= 16040 FOR UPDATE` (next-key locks) | Insert into the range waits, so the count stays the same |
| L4a | SERIALIZABLE | None | Implicit row S lock (InnoDB adds `FOR SHARE` to every plain SELECT) | Only the row being read is blocked |
| L4b | SERIALIZABLE | None | `LOCK TABLES film_rental READ` (table lock) | **Every** write to the table is blocked, even unrelated rows |

---

## Scripts

All located in [`tests/locks/`](../../tests/locks/):

| File | Session | Purpose |
| :--- | :---: | :--- |
| `l1-t1-writer.sql` | T1 | Updates rental 11496, holds it uncommitted for 6 s, rolls back |
| `l1-t2-reader.sql` | T2 | READ UNCOMMITTED. Plain read (dirty), then a `FOR SHARE` read (blocks, clean) |
| `l2-t1-reader.sql` | T1 | READ COMMITTED. Read 1 `FOR UPDATE`, sleep 6 s, Read 2 |
| `l2-t2-writer.sql` | T2 | Updates rental 11496 and commits |
| `l3-t1-range.sql` | T1 | REPEATABLE READ. Counts `rental_id >= 16040` `FOR UPDATE` twice, 6 s apart |
| `l3-t2-insert.sql` | T2 | Inserts rental 16050 into that range |
| `l4-t1-serializable.sql` | T1 | SERIALIZABLE. Reads rental 11496 twice, 6 s apart (implicit row lock) |
| `l4-t1-table-lock.sql` | T1 | Same reads, but holds `LOCK TABLES film_rental READ` |
| `l4-t2-writer.sql` | T2 | Updates an unrelated row (rental 1), then rental 11496 |
| `run.sh` | Both | Runs all 5 cases, takes a lock snapshot while T2 waits, saves timelines to `results/`, resets the data |

T2 always starts 1.5 s after T1, and T1 holds its lock for 6 s, so a blocked T2 waits about **4.5 s**.

---

## Run

From the repository root, with the MySQL container running:

```sh
./tests/locks/run.sh
```

Each `results/<case>.txt` has the merged timeline and a snapshot of `performance_schema.data_locks` / `metadata_locks` taken at about 3 s, while T2 is waiting. The snapshot shows exactly which lock T2 is waiting on, which makes a good screenshot for the report.

The script resets rental 11496, rental 1 and deletes rental 16050 before and after each case.

---

## Results

### L1: READ UNCOMMITTED + `FOR SHARE` (dirty read)

| Time | T1 (writer) | T2 (reader, READ UNCOMMITTED) |
| :--- | :--- | :--- |
| 0.00 s | `START TRANSACTION`<br>`UPDATE ... SET return_date = '2006-02-20 10:00:00'` (X lock on 11496) | |
| 1.50 s | | `SELECT return_date` → **2006-02-20 10:00:00** (dirty) |
| 1.50 s | | `SELECT return_date ... FOR SHARE` → **BLOCKED** (needs S lock) |
| 6.00 s | `ROLLBACK` (releases X lock) | |
| 6.00 s | | `FOR SHARE` read returns **NULL** (waited 4.5 s) |

Lock snapshot at 3 s: T1 holds `X,REC_NOT_GAP` on 11496, and T2 is `WAITING` for `S,REC_NOT_GAP` on 11496.

**Takeaway:** A locking read ignores READ UNCOMMITTED. It can't get its S lock while another transaction holds an X lock, so it can never see uncommitted data. The plain read in the same transaction still reads dirty, so the lock only protects the reads that ask for it.

### L2: READ COMMITTED + `FOR UPDATE` (non-repeatable read)

| Time | T1 (reader, READ COMMITTED) | T2 (writer) |
| :--- | :--- | :--- |
| 0.00 s | `START TRANSACTION`<br>`SELECT ... FOR UPDATE` → **NULL** (X lock on 11496) | |
| 1.50 s | | `UPDATE ... SET return_date = '2006-02-25 15:30:00'` → **BLOCKED** |
| 6.00 s | `SELECT return_date` → **NULL** (same as read 1) | |
| 6.00 s | `COMMIT` (releases lock) | |
| 6.00 s | | `UPDATE` completes (waited 4.5 s), `COMMIT` |

Compare with the baseline: at READ COMMITTED without the lock, read 2 returned `2006-02-25 15:30:00`.

**Takeaway:** `FOR UPDATE` makes the row stable for the whole transaction, even at READ COMMITTED. T2's update isn't lost. It just runs after T1 finishes.

### L3: REPEATABLE READ + next-key locks (phantom read)

| Time | T1 (range reader, REPEATABLE READ) | T2 (inserter) |
| :--- | :--- | :--- |
| 0.00 s | `START TRANSACTION`<br>`SELECT COUNT(*) ... WHERE rental_id >= 16040 FOR UPDATE` → **10** | |
| 1.50 s | | `INSERT ... rental_id = 16050` → **BLOCKED** |
| 6.00 s | Same count `FOR UPDATE` → **10** (no phantom) | |
| 6.00 s | `COMMIT` | |
| 6.00 s | | `INSERT` completes (waited 4.5 s) |

Lock snapshot at 3 s: T1 holds next-key `X` locks on every row from 16040 up, **plus the `supremum pseudo-record`** (the gap after the last row). T2 is `WAITING` with `X,INSERT_INTENTION` on the supremum.

**Takeaway:** A plain SELECT at REPEATABLE READ already avoids phantoms because it reads from a snapshot. A *locking* read or an `UPDATE` reads the latest data, though, so without gap locks it would see the new row. Next-key locks lock the gaps between rows, so new rows can't appear in the range at all.

### L4a vs L4b: SERIALIZABLE row locks vs explicit table lock

SERIALIZABLE already prevents all three anomalies, so this case compares **lock granularity** instead.

| Time | T1 (SERIALIZABLE, row lock) | T2 (writer) |
| :--- | :--- | :--- |
| 0.00 s | `SELECT` rental 11496 → NULL (implicit S lock) | |
| 1.50 s | | `UPDATE` rental **1** → done immediately |
| 1.50 s | | `UPDATE` rental **11496** → **BLOCKED** |
| 6.00 s | `SELECT` → NULL, `COMMIT` | |
| 6.00 s | | Update 11496 completes (waited 4.5 s) |

| Time | T1 (`LOCK TABLES film_rental READ`) | T2 (writer) |
| :--- | :--- | :--- |
| 0.00 s | `SELECT` rental 11496 → NULL (whole table locked) | |
| 1.50 s | | `UPDATE` rental **1** → **BLOCKED** (unrelated row) |
| 6.00 s | `SELECT` → NULL, `UNLOCK TABLES` | |
| 6.00 s | | Both updates complete (waited 4.5 s) |

Lock snapshot: L4a shows a single `S,REC_NOT_GAP` on 11496. L4b shows no InnoDB row locks at all, only a `SHARED_READ_ONLY` metadata (table) lock granted to T1 and T2's `SHARED_WRITE` `PENDING`.

**Takeaway:** Both are correct, but the table lock serializes *every* writer. Row-level locking only makes transactions wait when they touch the same rows.

---

## Summary

| Case | Isolation level | Anomaly fixed? | T2 wait | Rows blocked |
| :--- | :--- | :---: | :---: | :--- |
| L1 | READ UNCOMMITTED | Dirty read: yes (for the `FOR SHARE` read) | ~4.5 s | 1 |
| L2 | READ COMMITTED | Non-repeatable read: yes | ~4.5 s | 1 |
| L3 | REPEATABLE READ | Phantom: yes | ~4.5 s | range + gap after it |
| L4a | SERIALIZABLE | n/a (already safe) | ~4.5 s (only on the shared row) | 1 |
| L4b | SERIALIZABLE + table lock | n/a | ~4.5 s (on **any** row) | whole table |

## Performance trade-offs

* **Waiting:** Every fix works by making the other transaction wait. In these tests the wait is about 4.5 s because T1 sleeps. In a real app, the wait equals how long the lock holder's transaction runs, so long transactions plus locks mean slow requests.
* **Lock scope:** Row lock < range/gap lock < table lock. The bigger the scope, the more unrelated transactions get blocked (L4b vs L4a). Gap locks can also block inserts that don't conflict logically, and if the WHERE column has no index, InnoDB locks every row it scans.
* **Deadlocks:** Two transactions that lock rows in opposite order wait on each other. InnoDB detects this and rolls one back (error 1213), so apps that use locking reads must be ready to retry.
* **Timeouts:** A blocked statement gives up after `innodb_lock_wait_timeout` (50 s by default) with error 1205.
* **Targeted vs blanket:** Locking reads let a lower isolation level (READ COMMITTED) protect only the critical reads, which is usually cheaper than running everything at SERIALIZABLE.

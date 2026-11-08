# Phantom Read Test

A **phantom read** happens when a transaction runs an aggregate or range query twice and the set of rows it covers changes in between, because another transaction inserted (or deleted) a matching row and committed. The lecture slides (Slides 06, slides 7 and 18) show it as `Avg(GPA)` and `Max(GPA)` running while another transaction inserts new students. A non-repeatable read changes the value of a row already read; a phantom read changes *which rows* match.

This test runs the same scenario at each of the 4 isolation levels against the [`film_rental`](../database/film-rental.md) table.

## Scenario

Customer `75` has 3 rentals that haven't been returned yet (`return_date` is `NULL`), all rented on `2006-02-14 15:16:03`.

- **T1** (a manager) runs two aggregates over customer 75's unreturned rentals, `COUNT(*)` and `MAX(rental_date)`, sleeps 6 seconds (`DO SLEEP(6)`), then runs the same aggregates again.
- **T2** (a clerk) starts 1.5 seconds later, inserts a new unreturned rental `16050` (ACADEMY DINOSAUR, rented `2006-02-25 15:30:00`) for customer 75, sleeps 2 seconds, and commits.

If T1's second read returns `COUNT=4` and a later `MAX(rental_date)`, T1 saw a phantom row.

## Scripts

All in [`tests/phantom-read/`](../../tests/phantom-read/):

| File | Session | Purpose |
| --- | --- | --- |
| `t1-read-uncommitted.sql` | T1 | Reader at READ UNCOMMITTED |
| `t1-read-committed.sql` | T1 | Reader at READ COMMITTED |
| `t1-repeatable-read.sql` | T1 | Reader at REPEATABLE READ |
| `t1-serializable.sql` | T1 | Reader at SERIALIZABLE |
| `t2-insert.sql` | T2 | Inserts rental 16050, sleeps 2 s, commits. Same for every level. |
| `run.sh` | both | Runs all 4 cases and saves each one as a timeline in `results/` |

The scripts follow the template on slide 13: each session sets its own isolation level, T1 does `SELECT`, `<sleep>`, `SELECT`, and T2 does its write, `<sleep>`, `COMMIT`.

Each step prints a label, a `SYSDATE(6)` timestamp, and the aggregates T1 saw, so the output shows the order the two sessions ran in.

T2 commits its insert, so `run.sh` deletes rental 16050 before and after every case. The scripts are safe to rerun.

## Run all 4 cases

From the repo root, with the database up (macOS, Linux, or Git Bash/WSL on Windows). It takes about 35 seconds:

```sh
./tests/phantom-read/run.sh
```

```text
Isolation level    | T1 Read 1                                      | T1 Read 2                                      | T2 waited | Phantom?
-------------------+------------------------------------------------+------------------------------------------------+-----------+----------
READ UNCOMMITTED   | COUNT=3, MAX(rental_date)=2006-02-14 15:16:03  | COUNT=4, MAX(rental_date)=2006-02-25 15:30:00  |     0.00s | YES
READ COMMITTED     | COUNT=3, MAX(rental_date)=2006-02-14 15:16:03  | COUNT=4, MAX(rental_date)=2006-02-25 15:30:00  |     0.00s | YES
REPEATABLE READ    | COUNT=3, MAX(rental_date)=2006-02-14 15:16:03  | COUNT=3, MAX(rental_date)=2006-02-14 15:16:03  |     0.00s | no
SERIALIZABLE       | COUNT=3, MAX(rental_date)=2006-02-14 15:16:03  | COUNT=3, MAX(rental_date)=2006-02-14 15:16:03  |     4.47s | no
```

Each case is saved as a simple timeline of both sessions in `tests/phantom-read/results/<level>.txt`, ending with the result. For example, `serializable.txt`:

```text
   time     who  step                                         aggregates
   0.00 s   T1   start (SERIALIZABLE)
   0.01 s   T1   read 1                                       COUNT=3, MAX(rental_date)=2006-02-14 15:16:03
   1.55 s   T2   start (REPEATABLE-READ)
   1.55 s   T2   insert BLOCKED (T1 holds gap locks)
   6.02 s   T1   read 2                                       COUNT=3, MAX(rental_date)=2006-02-14 15:16:03
   6.02 s   T1   committed
   6.02 s   T2   inserted after waiting 4.47 s (uncommitted)  rental 16050
   8.03 s   T2   committed                                    rental 16050

Result: NO PHANTOM: T1 saw 'COUNT=3, MAX(rental_date)=2006-02-14 15:16:03' on both reads although T2 inserted and committed rental 16050. T2's insert was blocked for 4.47 s.
```

## Run one case by hand

Open two terminals in the repo root and load `.env` in each, so the password is passed to MySQL:

```sh
set -a; . ./.env; set +a
```

Then run one script per terminal:

```sh
# Terminal 1 (T1): start this first, picking the level to test
docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" sakila-mysql-group mysql -u sakila sakila --table < tests/phantom-read/t1-read-uncommitted.sql

# Terminal 2 (T2): start within 4 seconds, so the insert commits before T1's second read
docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" sakila-mysql-group mysql -u sakila sakila --table < tests/phantom-read/t2-insert.sql
```

Afterwards, remove the inserted row so the next run starts from the same data:

```sh
docker exec -i -e MYSQL_PWD="$MYSQL_PASSWORD" sakila-mysql-group mysql -u sakila sakila -e "DELETE FROM film_rental WHERE rental_id = 16050;"
```

## Results

Times are seconds after T1 starts. Values are what each session saw in the actual run.

### Case 1: READ UNCOMMITTED, phantom read occurs

| T1 (reader, READ UNCOMMITTED) | T2 (inserter) |
| --- | --- |
| 0 s: `START TRANSACTION` | |
| 0 s: read 1 returns `COUNT=3`, `MAX(rental_date)=2006-02-14 15:16:03` | |
| `DO SLEEP(6)` | 1.5 s: `START TRANSACTION` |
| | 1.5 s: `INSERT ... VALUES (16050, 'ACADEMY DINOSAUR', 75, '2006-02-25 15:30:00', NULL)` |
| | `DO SLEEP(2)` |
| | 3.5 s: `COMMIT` |
| 6 s: read 2 returns **`COUNT=4`**, **`MAX(rental_date)=2006-02-25 15:30:00`** | |
| 6 s: `COMMIT` | |

Both aggregates changed inside one transaction because rental 16050 appeared. **Phantom read: yes.**

### Case 2: READ COMMITTED, phantom read occurs

| T1 (reader, READ COMMITTED) | T2 (inserter) |
| --- | --- |
| 0 s: `START TRANSACTION` | |
| 0 s: read 1 returns `COUNT=3`, `MAX(rental_date)=2006-02-14 15:16:03` | |
| `DO SLEEP(6)` | 1.5 s: `START TRANSACTION` |
| | 1.5 s: `INSERT ... VALUES (16050, 'ACADEMY DINOSAUR', 75, '2006-02-25 15:30:00', NULL)` |
| | `DO SLEEP(2)` |
| | 3.5 s: `COMMIT` |
| 6 s: read 2 returns **`COUNT=4`**, **`MAX(rental_date)=2006-02-25 15:30:00`** | |
| 6 s: `COMMIT` | |

**Phantom read: yes.**

### Case 3: REPEATABLE READ, no phantom read

| T1 (reader, REPEATABLE READ) | T2 (inserter) |
| --- | --- |
| 0 s: `START TRANSACTION` | |
| 0 s: read 1 returns `COUNT=3`, `MAX(rental_date)=2006-02-14 15:16:03` | |
| `DO SLEEP(6)` | 1.5 s: `START TRANSACTION` |
| | 1.5 s: `INSERT ... VALUES (16050, 'ACADEMY DINOSAUR', 75, '2006-02-25 15:30:00', NULL)` (no wait) |
| | `DO SLEEP(2)` |
| | 3.5 s: `COMMIT` |
| 6 s: read 2 returns `COUNT=3`, `MAX(rental_date)=2006-02-14 15:16:03` | |
| 6 s: `COMMIT` | |

**Phantom read: no.** The slides (slide 10) list phantoms as possible at this level, but InnoDB prevents them for plain `SELECT`s.

### Case 4: SERIALIZABLE, no phantom read (T2 blocks)

| T1 (reader, SERIALIZABLE) | T2 (inserter) |
| --- | --- |
| 0 s: `START TRANSACTION` | |
| 0 s: read 1 returns `COUNT=3`, `MAX(rental_date)=2006-02-14 15:16:03` (locks the rows and gaps it scanned) | |
| `DO SLEEP(6)` | 1.5 s: `START TRANSACTION` |
| | 1.5 s: `INSERT ... VALUES (16050, ...)` **blocks**, waiting for T1's gap lock |
| 6 s: read 2 returns `COUNT=3`, `MAX(rental_date)=2006-02-14 15:16:03` | |
| 6 s: `COMMIT` (releases the locks) | 6 s: insert goes through after waiting 4.47 s |
| | `DO SLEEP(2)` |
| | 8 s: `COMMIT` |

**Phantom read: no.** The price is the 4.47-second wait.

### Summary

| Isolation level | T1 read 1 | T1 read 2 | T2 waited | Phantom read? |
| --- | --- | --- | ---: | --- |
| READ UNCOMMITTED | `COUNT=3`, `MAX=2006-02-14 15:16:03` | `COUNT=4`, `MAX=2006-02-25 15:30:00` | 0.00 s | **Yes** |
| READ COMMITTED | `COUNT=3`, `MAX=2006-02-14 15:16:03` | `COUNT=4`, `MAX=2006-02-25 15:30:00` | 0.00 s | **Yes** |
| REPEATABLE READ | `COUNT=3`, `MAX=2006-02-14 15:16:03` | `COUNT=3`, `MAX=2006-02-14 15:16:03` | 0.00 s | No |
| SERIALIZABLE | `COUNT=3`, `MAX=2006-02-14 15:16:03` | `COUNT=3`, `MAX=2006-02-14 15:16:03` | 4.47 s | No |

### Why

- **READ UNCOMMITTED** reads the newest version of every row. Once T2's insert exists, T1's next read counts it.
- **READ COMMITTED** uses consistent (non-locking) reads, but builds a new snapshot for every statement. T2 committed before read 2, so read 2's snapshot includes rental 16050.
- **REPEATABLE READ** also uses consistent reads, but keeps the snapshot from read 1 for the whole transaction. Rental 16050 was committed after that snapshot, so T1 never sees it, and T2 doesn't wait. The SQL standard and the slides allow phantoms at this level; InnoDB's snapshot is stricter than that.
- **SERIALIZABLE** turns a plain `SELECT` inside a transaction into `SELECT ... FOR SHARE`. `customer_id` has no index, so InnoDB scans the whole primary key and takes shared next-key locks (each row plus the gap before it), including the gap after the last row where 16050 goes. T2's insert needs that gap, so it waits until T1 commits. The two transactions end up running as the serial order T1 then T2 (slide 20).

## Notes

- **SERIALIZABLE wait:** T2's terminal hangs with no output at the insert. That is the expected result, not a freeze. It finishes when T1 commits.
- **Lock timeout:** if T2 waits longer than 50 seconds (`innodb_lock_wait_timeout`), it fails with `ERROR 1205 (HY000): Lock wait timeout exceeded`. T1 only holds its locks for about 6 seconds, so this won't happen with these scripts.
- **Explicit transaction:** the T1 scripts use `START TRANSACTION`. Without it, `autocommit` makes each `SELECT` its own transaction, so each read gets a new snapshot and SERIALIZABLE releases its locks right away. Both reads would then see the phantom.
- **Reader's level matters:** a phantom read depends on T1's isolation level, not T2's. T2 stays on the default level, `REPEATABLE READ` (slide 21), in every case.
- **Locking reads at REPEATABLE READ:** `SELECT ... FOR UPDATE` or `FOR SHARE` reads the latest committed rows instead of the snapshot, and uses next-key locks to block inserts into the range. That is covered in the lock experiments.

# film_rental

Simplified transaction table for the isolation-level exercises. It's built from Sakila's `rental`, `inventory` and `film` tables and uses the InnoDB engine, because MyISAM doesn't support transactions.

It's created automatically on the first `docker compose up` (see [`film-rental.sql`](film-rental.sql)).

## Definition

```sql
CREATE TABLE film_rental (
  rental_id   INT UNSIGNED NOT NULL,
  title       VARCHAR(255) NOT NULL,
  customer_id SMALLINT UNSIGNED NOT NULL,
  rental_date DATETIME NOT NULL,
  return_date DATETIME NULL,
  PRIMARY KEY (rental_id)
) ENGINE=InnoDB;
```

| Column | Type | Key | Null | Source |
| --- | --- | --- | --- | --- |
| `rental_id` | int unsigned | PK | NOT NULL | `rental.rental_id` |
| `title` | varchar(255) |  | NOT NULL | `film.title` (via `inventory.film_id`) |
| `customer_id` | smallint unsigned |  | NOT NULL | `rental.customer_id` |
| `rental_date` | datetime |  | NOT NULL | `rental.rental_date` |
| `return_date` | datetime |  |  | `rental.return_date` (`NULL` = not yet returned) |

16,044 rows, one per Sakila rental.

## First 5 rows

| rental_id | title | customer_id | rental_date | return_date |
| --- | --- | --- | --- | --- |
| 1 | BLANKET BEVERLY | 130 | 2005-05-24 22:53:30 | 2005-05-26 22:04:30 |
| 2 | FREAKY POCUS | 459 | 2005-05-24 22:54:33 | 2005-05-28 19:40:33 |
| 3 | GRADUATE LORD | 408 | 2005-05-24 23:03:39 | 2005-06-01 22:12:39 |
| 4 | LOVE SUICIDES | 333 | 2005-05-24 23:04:41 | 2005-06-03 01:43:41 |
| 5 | IDOLS SNATCHERS | 222 | 2005-05-24 23:05:21 | 2005-06-02 04:33:21 |

## Check the engine

```sql
SELECT table_name, engine
FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_name = 'film_rental';
```

## Recreate

To rebuild the table with its original data without resetting the whole database:

```sh
docker exec -i sakila-mysql-group mysql -u sakila -p sakila < film-rental.sql
```

-- Simplified rental table for the isolation-level transaction exercises.
-- InnoDB is required: MyISAM does not support transactions.
DROP TABLE IF EXISTS film_rental;

CREATE TABLE film_rental (
  rental_id   INT UNSIGNED NOT NULL,
  title       VARCHAR(255) NOT NULL,
  customer_id SMALLINT UNSIGNED NOT NULL,
  rental_date DATETIME NOT NULL,
  return_date DATETIME NULL,
  PRIMARY KEY (rental_id)
) ENGINE=InnoDB;

INSERT INTO film_rental (rental_id, title, customer_id, rental_date, return_date)
SELECT r.rental_id, f.title, r.customer_id, r.rental_date, r.return_date
FROM rental r
JOIN inventory i ON i.inventory_id = r.inventory_id
JOIN film f ON f.film_id = i.film_id;

# Sakila Schema

MySQL 8.4 Sakila database as loaded by [`db/init-sakila.sh`](../../db/init-sakila.sh): 16 base tables, their columns and keys, and the first 5 rows of each (ordered by primary key).

Views are not shown. The `film_rental` table used for the transaction exercises is documented in [film-rental.md](film-rental.md).

## Entity relationship diagram

```mermaid
erDiagram
  actor {
    int actor_id PK
    varchar first_name
    varchar last_name
    timestamp last_update
  }
  address {
    int address_id PK
    varchar address
    varchar address2
    varchar district
    int city_id FK
    varchar postal_code
    varchar phone
    timestamp last_update
  }
  category {
    int category_id PK
    varchar name
    timestamp last_update
  }
  city {
    int city_id PK
    varchar city
    int country_id FK
    timestamp last_update
  }
  country {
    int country_id PK
    varchar country
    timestamp last_update
  }
  customer {
    int customer_id PK
    int store_id FK
    varchar first_name
    varchar last_name
    varchar email
    int address_id FK
    tinyint active
    datetime create_date
    timestamp last_update
  }
  film {
    int film_id PK
    varchar title
    text description
    year release_year
    int language_id FK
    int original_language_id FK
    tinyint rental_duration
    decimal rental_rate
    smallint length
    decimal replacement_cost
    enum rating
    set special_features
    timestamp last_update
  }
  film_actor {
    int actor_id PK, FK
    int film_id PK, FK
    timestamp last_update
  }
  film_category {
    int film_id PK, FK
    int category_id PK, FK
    timestamp last_update
  }
  film_text {
    int film_id PK
    varchar title
    text description
  }
  inventory {
    int inventory_id PK
    int film_id FK
    int store_id FK
    timestamp last_update
  }
  language {
    int language_id PK
    char name
    timestamp last_update
  }
  payment {
    int payment_id PK
    int customer_id FK
    int staff_id FK
    int rental_id FK
    decimal amount
    datetime payment_date
    timestamp last_update
  }
  rental {
    int rental_id PK
    datetime rental_date
    int inventory_id FK
    int customer_id FK
    datetime return_date
    int staff_id FK
    timestamp last_update
  }
  staff {
    int staff_id PK
    varchar first_name
    varchar last_name
    int address_id FK
    mediumblob picture
    varchar email
    int store_id FK
    tinyint active
    varchar username
    varchar password
    timestamp last_update
  }
  store {
    int store_id PK
    int manager_staff_id FK
    int address_id FK
    timestamp last_update
  }
  city ||--o{ address : "city_id"
  country ||--o{ city : "country_id"
  store ||--o{ customer : "store_id"
  address ||--o{ customer : "address_id"
  language ||--o{ film : "language_id"
  language ||--o{ film : "original_language_id"
  actor ||--o{ film_actor : "actor_id"
  film ||--o{ film_actor : "film_id"
  film ||--o{ film_category : "film_id"
  category ||--o{ film_category : "category_id"
  film ||--o{ inventory : "film_id"
  store ||--o{ inventory : "store_id"
  customer ||--o{ payment : "customer_id"
  staff ||--o{ payment : "staff_id"
  rental ||--o{ payment : "rental_id"
  inventory ||--o{ rental : "inventory_id"
  customer ||--o{ rental : "customer_id"
  staff ||--o{ rental : "staff_id"
  address ||--o{ staff : "address_id"
  store ||--o{ staff : "store_id"
  staff ||--o{ store : "manager_staff_id"
  address ||--o{ store : "address_id"
```

## Tables

| Table | Group | Rows | Columns |
| --- | --- | ---: | ---: |
| [`rental`](#rental) | Transactions | 16,044 | 7 |
| [`payment`](#payment) | Transactions | 16,049 | 7 |
| [`inventory`](#inventory) | Transactions | 4,581 | 4 |
| [`film`](#film) | Film catalog | 1,000 | 13 |
| [`film_text`](#film_text) | Film catalog | 1,000 | 3 |
| [`film_actor`](#film_actor) | Film catalog | 5,462 | 3 |
| [`actor`](#actor) | Film catalog | 200 | 4 |
| [`film_category`](#film_category) | Film catalog | 1,000 | 3 |
| [`category`](#category) | Film catalog | 16 | 3 |
| [`language`](#language) | Film catalog | 6 | 3 |
| [`customer`](#customer) | People & stores | 599 | 9 |
| [`staff`](#staff) | People & stores | 2 | 11 |
| [`store`](#store) | People & stores | 2 | 4 |
| [`address`](#address) | Location | 603 | 8 |
| [`city`](#city) | Location | 600 | 4 |
| [`country`](#country) | Location | 109 | 3 |

## Transactions

### rental

16,044 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `rental_id` | int | PK | NOT NULL |
| `rental_date` | datetime |  | NOT NULL |
| `inventory_id` | int unsigned | FK → `inventory` | NOT NULL |
| `customer_id` | int unsigned | FK → `customer` | NOT NULL |
| `return_date` | datetime |  |  |
| `staff_id` | int unsigned | FK → `staff` | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| rental_id | rental_date | inventory_id | customer_id | return_date | staff_id | last_update |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 2005-05-24 22:53:30 | 367 | 130 | 2005-05-26 22:04:30 | 1 | 2006-02-15 21:30:53 |
| 2 | 2005-05-24 22:54:33 | 1525 | 459 | 2005-05-28 19:40:33 | 1 | 2006-02-15 21:30:53 |
| 3 | 2005-05-24 23:03:39 | 1711 | 408 | 2005-06-01 22:12:39 | 1 | 2006-02-15 21:30:53 |
| 4 | 2005-05-24 23:04:41 | 2452 | 333 | 2005-06-03 01:43:41 | 2 | 2006-02-15 21:30:53 |
| 5 | 2005-05-24 23:05:21 | 2079 | 222 | 2005-06-02 04:33:21 | 1 | 2006-02-15 21:30:53 |

### payment

16,049 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `payment_id` | int unsigned | PK | NOT NULL |
| `customer_id` | int unsigned | FK → `customer` | NOT NULL |
| `staff_id` | int unsigned | FK → `staff` | NOT NULL |
| `rental_id` | int | FK → `rental` |  |
| `amount` | decimal(5,2) |  | NOT NULL |
| `payment_date` | datetime |  | NOT NULL |
| `last_update` | timestamp |  |  |

**First 5 rows**

| payment_id | customer_id | staff_id | rental_id | amount | payment_date | last_update |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | 1 | 76 | 2.99 | 2005-05-25 11:30:37 | 2006-02-15 22:12:30 |
| 2 | 1 | 1 | 573 | 0.99 | 2005-05-28 10:35:23 | 2006-02-15 22:12:30 |
| 3 | 1 | 1 | 1185 | 5.99 | 2005-06-15 00:54:12 | 2006-02-15 22:12:30 |
| 4 | 1 | 2 | 1422 | 0.99 | 2005-06-15 18:02:53 | 2006-02-15 22:12:30 |
| 5 | 1 | 2 | 1476 | 9.99 | 2005-06-15 21:08:46 | 2006-02-15 22:12:30 |

### inventory

4,581 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `inventory_id` | int unsigned | PK | NOT NULL |
| `film_id` | int unsigned | FK → `film` | NOT NULL |
| `store_id` | int unsigned | FK → `store` | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| inventory_id | film_id | store_id | last_update |
| --- | --- | --- | --- |
| 1 | 1 | 1 | 2006-02-15 05:09:17 |
| 2 | 1 | 1 | 2006-02-15 05:09:17 |
| 3 | 1 | 1 | 2006-02-15 05:09:17 |
| 4 | 1 | 1 | 2006-02-15 05:09:17 |
| 5 | 1 | 2 | 2006-02-15 05:09:17 |

## Film catalog

### film

1,000 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `film_id` | int unsigned | PK | NOT NULL |
| `title` | varchar(255) |  | NOT NULL |
| `description` | text |  |  |
| `release_year` | year |  |  |
| `language_id` | int unsigned | FK → `language` | NOT NULL |
| `original_language_id` | int unsigned | FK → `language` |  |
| `rental_duration` | tinyint unsigned |  | NOT NULL |
| `rental_rate` | decimal(4,2) |  | NOT NULL |
| `length` | smallint unsigned |  |  |
| `replacement_cost` | decimal(5,2) |  | NOT NULL |
| `rating` | enum('G','PG','PG-13','R','NC-17') |  |  |
| `special_features` | set('Trailers','Commentaries','Deleted Scenes','Behind the Scenes') |  |  |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| film_id | title | description | release_year | language_id | original_language_id | rental_duration | rental_rate | length | replacement_cost | rating | special_features | last_update |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | ACADEMY DINOSAUR | A Epic Drama of a Feminist And a Mad Scientist who must B… | 2006 | 1 | _null_ | 6 | 0.99 | 86 | 20.99 | PG | Deleted Scenes,Behind the Scenes | 2006-02-15 05:03:42 |
| 2 | ACE GOLDFINGER | A Astounding Epistle of a Database Administrator And a Ex… | 2006 | 1 | _null_ | 3 | 4.99 | 48 | 12.99 | G | Trailers,Deleted Scenes | 2006-02-15 05:03:42 |
| 3 | ADAPTATION HOLES | A Astounding Reflection of a Lumberjack And a Car who mus… | 2006 | 1 | _null_ | 7 | 2.99 | 50 | 18.99 | NC-17 | Trailers,Deleted Scenes | 2006-02-15 05:03:42 |
| 4 | AFFAIR PREJUDICE | A Fanciful Documentary of a Frisbee And a Lumberjack who … | 2006 | 1 | _null_ | 5 | 2.99 | 117 | 26.99 | G | Commentaries,Behind the Scenes | 2006-02-15 05:03:42 |
| 5 | AFRICAN EGG | A Fast-Paced Documentary of a Pastry Chef And a Dentist w… | 2006 | 1 | _null_ | 6 | 2.99 | 130 | 22.99 | G | Deleted Scenes | 2006-02-15 05:03:42 |

### film_text

1,000 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `film_id` | int | PK | NOT NULL |
| `title` | varchar(255) |  | NOT NULL |
| `description` | text |  |  |

**First 5 rows**

| film_id | title | description |
| --- | --- | --- |
| 1 | ACADEMY DINOSAUR | A Epic Drama of a Feminist And a Mad Scientist who must B… |
| 2 | ACE GOLDFINGER | A Astounding Epistle of a Database Administrator And a Ex… |
| 3 | ADAPTATION HOLES | A Astounding Reflection of a Lumberjack And a Car who mus… |
| 4 | AFFAIR PREJUDICE | A Fanciful Documentary of a Frisbee And a Lumberjack who … |
| 5 | AFRICAN EGG | A Fast-Paced Documentary of a Pastry Chef And a Dentist w… |

### film_actor

5,462 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `actor_id` | int unsigned | PK, FK → `actor` | NOT NULL |
| `film_id` | int unsigned | PK, FK → `film` | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| actor_id | film_id | last_update |
| --- | --- | --- |
| 1 | 1 | 2006-02-15 05:05:03 |
| 1 | 23 | 2006-02-15 05:05:03 |
| 1 | 25 | 2006-02-15 05:05:03 |
| 1 | 106 | 2006-02-15 05:05:03 |
| 1 | 140 | 2006-02-15 05:05:03 |

### actor

200 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `actor_id` | int unsigned | PK | NOT NULL |
| `first_name` | varchar(45) |  | NOT NULL |
| `last_name` | varchar(45) |  | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| actor_id | first_name | last_name | last_update |
| --- | --- | --- | --- |
| 1 | PENELOPE | GUINESS | 2006-02-15 04:34:33 |
| 2 | NICK | WAHLBERG | 2006-02-15 04:34:33 |
| 3 | ED | CHASE | 2006-02-15 04:34:33 |
| 4 | JENNIFER | DAVIS | 2006-02-15 04:34:33 |
| 5 | JOHNNY | LOLLOBRIGIDA | 2006-02-15 04:34:33 |

### film_category

1,000 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `film_id` | int unsigned | PK, FK → `film` | NOT NULL |
| `category_id` | int unsigned | PK, FK → `category` | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| film_id | category_id | last_update |
| --- | --- | --- |
| 1 | 6 | 2006-02-15 05:07:09 |
| 2 | 11 | 2006-02-15 05:07:09 |
| 3 | 6 | 2006-02-15 05:07:09 |
| 4 | 11 | 2006-02-15 05:07:09 |
| 5 | 8 | 2006-02-15 05:07:09 |

### category

16 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `category_id` | int unsigned | PK | NOT NULL |
| `name` | varchar(25) |  | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| category_id | name | last_update |
| --- | --- | --- |
| 1 | Action | 2006-02-15 04:46:27 |
| 2 | Animation | 2006-02-15 04:46:27 |
| 3 | Children | 2006-02-15 04:46:27 |
| 4 | Classics | 2006-02-15 04:46:27 |
| 5 | Comedy | 2006-02-15 04:46:27 |

### language

6 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `language_id` | int unsigned | PK | NOT NULL |
| `name` | char(20) |  | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| language_id | name | last_update |
| --- | --- | --- |
| 1 | English | 2006-02-15 05:02:19 |
| 2 | Italian | 2006-02-15 05:02:19 |
| 3 | Japanese | 2006-02-15 05:02:19 |
| 4 | Mandarin | 2006-02-15 05:02:19 |
| 5 | French | 2006-02-15 05:02:19 |

## People & stores

### customer

599 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `customer_id` | int unsigned | PK | NOT NULL |
| `store_id` | int unsigned | FK → `store` | NOT NULL |
| `first_name` | varchar(45) |  | NOT NULL |
| `last_name` | varchar(45) |  | NOT NULL |
| `email` | varchar(50) |  |  |
| `address_id` | int unsigned | FK → `address` | NOT NULL |
| `active` | tinyint(1) |  | NOT NULL |
| `create_date` | datetime |  | NOT NULL |
| `last_update` | timestamp |  |  |

**First 5 rows**

| customer_id | store_id | first_name | last_name | email | address_id | active | create_date | last_update |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | MARY | SMITH | MARY.SMITH@sakilacustomer.org | 5 | 1 | 2006-02-14 22:04:36 | 2006-02-15 04:57:20 |
| 2 | 1 | PATRICIA | JOHNSON | PATRICIA.JOHNSON@sakilacustomer.org | 6 | 1 | 2006-02-14 22:04:36 | 2006-02-15 04:57:20 |
| 3 | 1 | LINDA | WILLIAMS | LINDA.WILLIAMS@sakilacustomer.org | 7 | 1 | 2006-02-14 22:04:36 | 2006-02-15 04:57:20 |
| 4 | 2 | BARBARA | JONES | BARBARA.JONES@sakilacustomer.org | 8 | 1 | 2006-02-14 22:04:36 | 2006-02-15 04:57:20 |
| 5 | 1 | ELIZABETH | BROWN | ELIZABETH.BROWN@sakilacustomer.org | 9 | 1 | 2006-02-14 22:04:36 | 2006-02-15 04:57:20 |

### staff

2 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `staff_id` | int unsigned | PK | NOT NULL |
| `first_name` | varchar(45) |  | NOT NULL |
| `last_name` | varchar(45) |  | NOT NULL |
| `address_id` | int unsigned | FK → `address` | NOT NULL |
| `picture` | mediumblob |  |  |
| `email` | varchar(50) |  |  |
| `store_id` | int unsigned | FK → `store` | NOT NULL |
| `active` | tinyint(1) |  | NOT NULL |
| `username` | varchar(16) |  | NOT NULL |
| `password` | varchar(40) |  |  |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| staff_id | first_name | last_name | address_id | picture | email | store_id | active | username | password | last_update |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Mike | Hillyer | 3 | _null_ | Mike.Hillyer@sakilastaff.com | 1 | 1 | Mike | 8cb2237d0679ca88db6464eac60da96345513964 | 2006-02-15 04:57:16 |
| 2 | Jon | Stephens | 4 | _null_ | Jon.Stephens@sakilastaff.com | 2 | 1 | Jon | 8cb2237d0679ca88db6464eac60da96345513964 | 2006-02-15 04:57:16 |

### store

2 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `store_id` | int unsigned | PK | NOT NULL |
| `manager_staff_id` | int unsigned | FK → `staff` | NOT NULL |
| `address_id` | int unsigned | FK → `address` | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| store_id | manager_staff_id | address_id | last_update |
| --- | --- | --- | --- |
| 1 | 1 | 1 | 2006-02-15 04:57:12 |
| 2 | 2 | 2 | 2006-02-15 04:57:12 |

## Location

### address

603 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `address_id` | int unsigned | PK | NOT NULL |
| `address` | varchar(50) |  | NOT NULL |
| `address2` | varchar(50) |  |  |
| `district` | varchar(20) |  | NOT NULL |
| `city_id` | int unsigned | FK → `city` | NOT NULL |
| `postal_code` | varchar(10) |  |  |
| `phone` | varchar(20) |  | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| address_id | address | address2 | district | city_id | postal_code | phone | last_update |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 47 MySakila Drive | _null_ |   | 300 | _null_ |   | 2006-02-15 04:45:30 |
| 2 | 28 MySQL Boulevard | _null_ |   | 576 | _null_ |   | 2006-02-15 04:45:30 |
| 3 | 23 Workhaven Lane | _null_ |   | 300 | _null_ |   | 2006-02-15 04:45:30 |
| 4 | 1411 Lillydale Drive | _null_ |   | 576 | _null_ |   | 2006-02-15 04:45:30 |
| 5 | 1913 Hanoi Way | _null_ |   | 463 | 35200 |   | 2006-02-15 04:45:30 |

### city

600 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `city_id` | int unsigned | PK | NOT NULL |
| `city` | varchar(50) |  | NOT NULL |
| `country_id` | int unsigned | FK → `country` | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| city_id | city | country_id | last_update |
| --- | --- | --- | --- |
| 1 | A Corua (La Corua) | 87 | 2006-02-15 04:45:25 |
| 2 | Abha | 82 | 2006-02-15 04:45:25 |
| 3 | Abu Dhabi | 101 | 2006-02-15 04:45:25 |
| 4 | Acua | 60 | 2006-02-15 04:45:25 |
| 5 | Adana | 97 | 2006-02-15 04:45:25 |

### country

109 rows

| Column | Type | Key | Null |
| --- | --- | --- | --- |
| `country_id` | int unsigned | PK | NOT NULL |
| `country` | varchar(50) |  | NOT NULL |
| `last_update` | timestamp |  | NOT NULL |

**First 5 rows**

| country_id | country | last_update |
| --- | --- | --- |
| 1 | Afghanistan | 2006-02-15 04:44:00 |
| 2 | Algeria | 2006-02-15 04:44:00 |
| 3 | American Samoa | 2006-02-15 04:44:00 |
| 4 | Angola | 2006-02-15 04:44:00 |
| 5 | Anguilla | 2006-02-15 04:44:00 |

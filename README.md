   # isolation-levels

Hands-On 3 for STADVDB: Isolation Levels

MySQL 8.4 with the Sakila sample database, running in Docker.

## Requirements

- [Docker](https://docs.docker.com/get-docker/) with Docker Compose (Windows, macOS, or Linux)

## Run

1. Create your `.env` file:

   ```sh
   cp .env.example .env              # macOS / Linux
   Copy-Item .env.example .env       # Windows PowerShell
   ```

2. Start the database:

   ```sh
   docker compose up -d
   ```

   The first start downloads and loads Sakila, which takes about 30 seconds. It's ready when `docker compose logs mysql` shows `Sakila Init] Complete!`.

## Usage

Open the MySQL client inside the container (enter `MYSQL_PASSWORD` from your `.env` when prompted):

```sh
docker exec -it sakila-mysql-group mysql -u sakila -p sakila
```

Use the user and database names from your `.env` if you changed them.

To connect from a GUI client (DBeaver, MySQL Workbench, etc.), use `localhost:3306` and the credentials in `.env`.

| Task | Command |
| --- | --- |
| Stop | `docker compose down` |
| Reset (delete data and reload Sakila) | `docker compose down -v` |

## Docs

- [Sakila schema](docs/database/schema.md)
- [`film_rental` table](docs/database/film-rental.md)
- [Dirty read test](docs/tests/dirty-read.md): run with `./tests/dirty-read/run.sh`
- [Non-repeatable read test](docs/tests/non-repeatable-read.md): run with `./tests/non-repeatable-read/run.sh`
- [Lock experiments](docs/tests/locks.md): run with `./tests/locks/run.sh`

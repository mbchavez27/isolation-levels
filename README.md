# isolation-levels

Hands-On 3 for STADVDB: Isolation Levels

PostgreSQL 15 with the Sakila sample database, running in Docker.

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

   The first start downloads and loads Sakila, which takes about a minute. It's ready when `docker compose logs postgres` shows `Sakila Init] Complete!`.

## Usage

Open psql inside the container:

```sh
docker exec -it sakila-postgres-group psql -U postgres -d sakila
```

Use the user and database names from your `.env` if you changed them.

To connect from a GUI client (DBeaver, pgAdmin, etc.), use `localhost:5432` and the credentials in `.env`.

| Task | Command |
| --- | --- |
| Stop | `docker compose down` |
| Reset (delete data and reload Sakila) | `docker compose down -v` |

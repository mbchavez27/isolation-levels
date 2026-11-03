#!/usr/bin/env sh
set -e

echo "=== [Sakila Init] Downloading Sakila Schema and Base Data ==="
curl -fsSL "https://raw.githubusercontent.com/jOOQ/sakila/main/mysql-sakila-db/mysql-sakila-schema.sql" -o /tmp/schema.sql
curl -fsSL "https://raw.githubusercontent.com/jOOQ/sakila/main/mysql-sakila-db/mysql-sakila-insert-data.sql" -o /tmp/data.sql

# The upstream scripts hardcode the "sakila" schema name; use our configured database instead.
sed -i "s/\([ (]\)sakila\([.;]\)/\1$MYSQL_DATABASE\2/g" /tmp/schema.sql /tmp/data.sql

export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"

echo "=== [Sakila Init] Loading Schema into MySQL ==="
mysql --user=root < /tmp/schema.sql

echo "=== [Sakila Init] Loading Base Sakila Data ==="
mysql --user=root < /tmp/data.sql

unset MYSQL_PWD
rm -f /tmp/schema.sql /tmp/data.sql
echo "=== [Sakila Init] Complete! Base Sakila database ready. ==="

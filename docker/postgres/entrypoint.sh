#!/bin/bash
set -eu

echo "version: $POSTGRES_VERSION"

cp /app/docker/postgres/configurations/ts_search/* /usr/share/postgresql/$POSTGRES_VERSION/tsearch_data/

CONFIG_FILE=/app/docker/postgres/postgresql.conf

if [ -f "$CONFIG_FILE"  ]
then
  echo "Postgres config file: $CONFIG_FILE"
else
   echo "ERROR: Postgres config file not found: $CONFIG_FILE"
   exit 1
fi

envsubst < $CONFIG_FILE > /etc/postgresql.conf

exec docker-entrypoint.sh "$@"

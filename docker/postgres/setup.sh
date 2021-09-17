#!/bin/bash
set -eu

echo "version: $POSTGRES_VERSION"

cp /app/config/configurations/ts_search/* /usr/share/postgresql/$POSTGRES_VERSION/tsearch_data/

LOCAL_CONFIG_FILE=/app/docker/postgres/postgresql.conf
CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/postgres/postgresql.conf

if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
    CONFIG_FILE=$LOCAL_CONFIG_FILE
fi

echo "Postgres config file: $CONFIG_FILE"

envsubst < $CONFIG_FILE > /etc/postgresql.conf

exec docker-entrypoint.sh "$@"

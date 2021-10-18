#!/bin/bash
set -eu

echo "version: $POSTGRES_VERSION"

if [ "$RAILS_ENV" == "development" ]
then
  cp -r /app$CORE_DUMMY_PREFIX/config/configurations/ts_search/ /usr/share/postgresql/$POSTGRES_VERSION/tsearch_data/
else
  cp /app/docker/postgres/configurations/ts_search/* /usr/share/postgresql/$POSTGRES_VERSION/tsearch_data/
fi

CONFIG_FILE=/app/docker/postgres/postgresql.conf
CORE_CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/postgres/postgresql.conf

if [ -f "$CONFIG_FILE"  ]
then
  echo "Postgres config file: $CONFIG_FILE"
else
  if [ "$RAILS_ENV" == "development" ] && [ -f "$CORE_CONFIG_FILE"  ]
  then
    echo "use core config file for local development: $CORE_CONFIG_FILE"
    CONFIG_FILE=$CORE_CONFIG_FILE
  else
    echo "ERROR: Postgres config file not found: $CONFIG_FILE"
    exit 1
  fi
fi

envsubst < $CONFIG_FILE > /etc/postgresql.conf

exec docker-entrypoint.sh "$@"

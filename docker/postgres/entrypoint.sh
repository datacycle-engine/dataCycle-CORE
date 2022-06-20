#!/bin/bash
set -eu

echo "version: $POSTGRES_VERSION"

if [ "$RAILS_ENV" == "development" ]
then
  [ "$(ls -A /app$CORE_DUMMY_PREFIX/config/configurations/ts_search/)" ] && cp /app$CORE_DUMMY_PREFIX/config/configurations/ts_search/* /usr/share/postgresql/$POSTGRES_VERSION/tsearch_data/.
else
  [ "$(ls -A /app/docker/postgres/configurations/ts_search/)" ] && cp /app/docker/postgres/configurations/ts_search/* /usr/share/postgresql/$POSTGRES_VERSION/tsearch_data/.
fi

CONFIG_FILE=/app/docker/postgres/postgresql.conf
ENV_CONFIG_FILE=/app/docker/$RAILS_ENV/postgres/postgresql.conf
CORE_CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/postgres/postgresql.conf

if [ -f "$ENV_CONFIG_FILE"  ]
then
  echo "$RAILS_ENV - Postgres config file: $ENV_CONFIG_FILE"
  CONFIG_FILE=$ENV_CONFIG_FILE
elif [ "$RAILS_ENV" != "development" ] && [ -f "$CONFIG_FILE" ]
then
  echo "Postgres config file: $CONFIG_FILE"
elif [ "$RAILS_ENV" == "development" ] && [ -f "$CORE_CONFIG_FILE" ]
then
  echo "use core config file for local development: $CORE_CONFIG_FILE"
  CONFIG_FILE=$CORE_CONFIG_FILE
else
  if [ "$CORE_DUMMY_PREFIX" != "" ]
  then
    echo "CORE using config file not found: $CONFIG_FILE"
  else
    echo "ERROR: Postgres config file not found: $CONFIG_FILE"
    exit 1
  fi
fi

envsubst < $CONFIG_FILE > /etc/postgresql.conf

exec docker-entrypoint.sh "$@"

#!/bin/bash
set -eu

mkdir -p /etc/redis

CONFIG_FILE=/app/docker/redis/redis.conf
CORE_CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/redis/redis.conf

if [ -f "$CONFIG_FILE"  ]
then
  echo "Redis config file: $CONFIG_FILE"
else
  if [ "$RAILS_ENV" == "development" ] && [ -f "$CORE_CONFIG_FILE"  ]
  then
    echo "use core config file for local development: $CORE_CONFIG_FILE"
    CONFIG_FILE=$CORE_CONFIG_FILE
  else
   echo "ERROR: Redis config file not found: $CONFIG_FILE"
   exit 1
  fi
fi

envsubst < $CONFIG_FILE > /etc/redis/redis.conf

exec docker-entrypoint.sh "$@"

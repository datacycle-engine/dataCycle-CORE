#!/bin/bash
set -eu

mkdir -p /etc/redis

CONFIG_FILE=/app/docker/redis/redis.conf

if [ -f "$CONFIG_FILE"  ]
then
  echo "Redis config file: $CONFIG_FILE"
else
   echo "ERROR: Redis config file not found: $CONFIG_FILE"
   exit 1
fi

envsubst < $CONFIG_FILE > /etc/redis/redis.conf

exec docker-entrypoint.sh "$@"

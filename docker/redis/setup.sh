#!/bin/bash
set -eu

mkdir -p /etc/redis

LOCAL_CONFIG_FILE=/app/docker/redis/redis.conf
CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/redis/redis.conf

if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
    CONFIG_FILE=$LOCAL_CONFIG_FILE
fi

echo "Redis config file: $CONFIG_FILE"

envsubst < $CONFIG_FILE > /etc/redis/redis.conf

exec docker-entrypoint.sh "$@"

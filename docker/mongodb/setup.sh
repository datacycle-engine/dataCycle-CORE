#!/bin/bash
set -eu

mkdir -p /etc/mongo

LOCAL_CONFIG_FILE=/app/docker/mongodb/mongod.conf
CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/mongodb/mongod.conf

if [[ -f "$LOCAL_CONFIG_FILE" ]]; then
    CONFIG_FILE=$LOCAL_CONFIG_FILE
fi

echo "MongoDB config file: $CONFIG_FILE"

envsubst < $CONFIG_FILE > /etc/mongo/mongod.conf
chown mongodb:mongodb /etc/mongo/mongod.conf

# mongo log file inside the container
mkdir -p /var/log/mongodb
chown -R mongodb:mongodb /var/log/mongodb

exec docker-entrypoint.sh "$@"

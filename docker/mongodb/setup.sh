#!/bin/sh
set -eu

# mongo config
mkdir -p /etc/mongo
envsubst < /tmp/mongodb/mongod.conf > /etc/mongo/mongod.conf
chown mongodb:mongodb /etc/mongo/mongod.conf

# mongo log file inside the container
mkdir -p /var/log/mongodb
chown -R mongodb:mongodb /var/log/mongodb

exec docker-entrypoint.sh "$@"

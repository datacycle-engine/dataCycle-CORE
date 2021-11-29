#!/bin/bash
set -eu

mkdir -p /etc/mongo

CONFIG_FILE=/app/docker/mongodb/mongod.conf
CORE_CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/mongodb/mongod.conf

if [ -f "$CONFIG_FILE"  ]
then
  echo "MongoDB config file: $CONFIG_FILE"
else
  if [ "$RAILS_ENV" == "development" ] && [ -f "$CORE_CONFIG_FILE"  ]
  then
    echo "use core config file for local development: $CORE_CONFIG_FILE"
    CONFIG_FILE=$CORE_CONFIG_FILE
  else
   echo "ERROR: MongoDB config file not found: $CONFIG_FILE"
   exit 1
  fi
fi

envsubst < $CONFIG_FILE > /etc/mongo/mongod.conf
chown mongodb:mongodb /etc/mongo/mongod.conf

# mongo log file inside the container
mkdir -p /var/log/mongodb
chown -R mongodb:mongodb /var/log/mongodb

exec docker-entrypoint.sh "$@"

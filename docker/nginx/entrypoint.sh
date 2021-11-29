#!/bin/sh
set -e

mkdir -p /etc/nginx/templates

CONFIG_FILE=/app/docker/nginx/templates/datacycle.conf.template
CORE_CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/nginx/templates/datacycle.conf.template

if [ -f "$CONFIG_FILE"  ]
then
  echo "Nginx config file: $CONFIG_FILE"
else
  if [ "$RAILS_ENV" == "development" ] && [ -f "$CORE_CONFIG_FILE"  ]
  then
    echo "use core config file for local development: $CORE_CONFIG_FILE"
    CONFIG_FILE=$CORE_CONFIG_FILE
  else
    echo "ERROR: Nginx config file not found: $CONFIG_FILE"
    exit 1
  fi
fi

cp $CONFIG_FILE /etc/nginx/templates/datacycle.conf.template

exec /docker-entrypoint.sh "$@"

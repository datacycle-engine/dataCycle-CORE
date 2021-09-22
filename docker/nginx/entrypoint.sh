#!/bin/sh
set -e

mkdir -p /etc/nginx/templates

CONFIG_FILE=/app/docker/nginx/templates/datacycle.conf.template

if [ -f "$CONFIG_FILE"  ]
then
  echo "Nginx config file: $CONFIG_FILE"
else
   echo "ERROR: Nginx config file not found: $CONFIG_FILE"
   exit 1
fi

cp $CONFIG_FILE /etc/nginx/templates/datacycle.conf.template

exec /docker-entrypoint.sh "$@"

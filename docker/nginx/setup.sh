#!/bin/sh
set -e

mkdir -p /etc/nginx/templates

LOCAL_CONFIG_FILE=/app/docker/nginx/templates/datacycle.conf.template
CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/nginx/templates/datacycle.conf.template

if [ -f "$LOCAL_CONFIG_FILE" ]; then CONFIG_FILE=$LOCAL_CONFIG_FILE; fi

cp $CONFIG_FILE /etc/nginx/templates/datacycle.conf.template

exec /docker-entrypoint.sh "$@"

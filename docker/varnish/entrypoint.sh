#!/bin/bash
set -e

# mkdir -p /var/lib/varnish/data

CONFIG_FILE=/app/docker/varnish/default.vcl
CORE_CONFIG_FILE=/app/vendor/gems/data-cycle-core/docker/varnish/default.vcl

if [ -f "$CONFIG_FILE"  ]
then
  echo "Varnish config file: $CONFIG_FILE"
else
  if [ "$RAILS_ENV" == "development" ] && [ -f "$CORE_CONFIG_FILE"  ]
  then
    echo "use core config file for local development: $CORE_CONFIG_FILE"
    CONFIG_FILE=$CORE_CONFIG_FILE
  else
   echo "ERROR: Varnish config file not found: $CONFIG_FILE"
   exit 1
  fi
fi

cp $CONFIG_FILE /var/lib/varnish/default.vcl

exec /usr/local/bin/docker-varnish-entrypoint "$@"

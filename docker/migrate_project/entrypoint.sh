#!/bin/bash
set -e

# make sure mandatory folders exist
mkdir -p /app${CORE_DUMMY_PREFIX:-}/tmp \
  && mkdir -p /app${CORE_DUMMY_PREFIX:-}/tmp/sockets \
  && mkdir -p /app${CORE_DUMMY_PREFIX:-}/tmp/pids \
  && chown ruby:ruby -R /app${CORE_DUMMY_PREFIX:-}/tmp

# update docker configs in named volumes
DC_CORE_PATH=/app/vendor/gems/data-cycle-core
if [ -d "$DC_CORE_PATH"  ]
then
  cp -Rn $DC_CORE_PATH/docker/* /app/dc_volumes/docker/.
  echo "$DC_CORE_PATH exists."
else
  echo "Running core only"
fi

rm -Rf /app/docker/* \
  && cp -Rf /app/dc_volumes/docker/* /app/docker/.

# update postgres ts_search config
mkdir -p /app/docker/postgres/configurations/ts_search/ && cp -Rn /app${CORE_DUMMY_PREFIX:-}/config/configurations/ts_search/* /app/docker/postgres/configurations/ts_search/.
chown -R ruby:ruby /app/docker

exec /app/docker-entrypoint.sh "$@"

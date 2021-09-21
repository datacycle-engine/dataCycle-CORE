#!/bin/bash
set -e

# make sure mandatory folders exist
mkdir -p /app/tmp && mkdir -p /app/tmp/sockets && mkdir -p /app/tmp/pids && chown ruby:ruby -R /app/tmp

# update docker configs in named volumes
cp -Rn /app/vendor/gems/data-cycle-core/docker/* /app/docker_tmp/.
mkdir -p /app/docker && rm -Rf /app/docker/* && cp -Rf /app/docker_tmp/* /app/docker/.
mkdir -p /app/docker/postgres/configurations/ts_search/ && cp -Rn /app/config/configurations/ts_search/* /app/docker/postgres/configurations/ts_search/.
chown -R ruby:ruby /app/docker

# update static vite build
rm -Rf /app/public/assets/* && cp -Rf /app/public/assets_tmp/* /app/public/assets/. && chown -R ruby:ruby /app/public/assets

exec /app/docker-entrypoint.sh "$@"

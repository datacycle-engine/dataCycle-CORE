#!/bin/bash
set -e

# make sure mandatory folders exist
mkdir -p /app/tmp/sockets && mkdir -p /app/tmp/pids && chown ruby:ruby -R /app/tmp

# copy helper script for postgres to local dir
mkdir -p /app/docker && cp /app/vendor/gems/data-cycle-core/docker/postgres/wait-for-postgres.sh /app/docker/. && chown ruby:ruby /app/docker/wait-for-postgres.sh && chmod +x /app/docker/wait-for-postgres.sh

exec "$@"

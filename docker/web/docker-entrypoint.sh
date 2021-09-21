#!/bin/bash
set -e

# make sure mandatory folders exist
mkdir -p /app/tmp && mkdir -p /app/tmp/sockets && mkdir -p /app/tmp/pids && chown ruby:ruby -R /app/tmp

exec "$@"

#!/bin/bash

cp /tmp/postgres/ts_search/* /usr/share/postgresql/13/tsearch_data/

envsubst < /tmp/postgres/postgresql.conf > /etc/postgresql.conf

exec docker-entrypoint.sh "$@"

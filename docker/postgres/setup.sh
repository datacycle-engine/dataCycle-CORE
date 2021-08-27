#!/bin/bash

cp /tmp/postgres/ts_search/* /usr/share/postgresql/13/tsearch_data/

docker-entrypoint.sh -c config_file=/etc/postgresql.conf

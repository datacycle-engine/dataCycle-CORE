#!/bin/bash

# check if db exists
bundle exec rake db:version

if [ $? -eq 0 ]
then
  echo "dataCycle database exists"
else
  echo "dataCycle database does not exists. Initialize database."
  exec /app/vendor/gems/data-cycle-core/docker/utility/initialize.sh
fi

set -e
# update project dictionaries if existing in main projects config/configurations/ts_search/
bundle exec rake dc:update:dictionaries

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

exec bundle exec puma -C /app/vendor/gems/data-cycle-core/docker/web/puma.rb "$@"
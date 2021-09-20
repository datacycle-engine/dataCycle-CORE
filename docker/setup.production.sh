#!/bin/bash

set -e

# update project dictionaries if existing in main projects config/configurations/ts_search/
bundle exec rake dc:update:dictionaries &

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

exec bundle exec puma -C /app/vendor/gems/data-cycle-core/docker/web/puma.rb "$@"




bundle exec rake data_cycle_core:update:import_classifications

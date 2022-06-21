#!/bin/bash
set -e

# post migration goes here
echo "### POST MIGRATIONS START ###"

# migrate data after restart
bundle exec rake ${CORE_RAKE_PREFIX:-}db:migrate:with_data

# run postgresql: VACUUM ANALYZE
bundle exec rake ${CORE_RAKE_PREFIX:-}db:maintenance:vacuum

# update computed attribtues
# bundle exec rake dc:update_data:computed_attributes

# cleanup db dumps
bundle exec rake ${CORE_RAKE_PREFIX:-}data_cycle_core:db:clean_up_dumps

bundle exec rake ${CORE_RAKE_PREFIX:-}dc:cache:clear_rails_cache

echo "### POST MIGRATIONS END ###"

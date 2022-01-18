#!/bin/bash
# post migration goes here

echo "### POST MIGRATIONS START ###"

# migrate data after restart
bundle exec rake db:migrate:with_data

# run postgresql: VACUUM ANALYZE
bundle exec rake db:maintenance:vacuum

# update computed attribtues
# bundle exec rake dc:update_data:computed_attributes

# cleanup db dumps
bundle exec rake data_cycle_core:db:clean_up_dumps

echo "### POST MIGRATIONS END ###"

#!/bin/bash
# post migration goes here

echo "### POST MIGRATIONS START ###"

# check if db exists
bundle exec rake db:version

# migrate data after restart
bundle exec rake db:migrate:with_data

# update computed attribtues
# bundle exec rake dc:update_data:computed_attributes

# cleanup db dumps
bundle exec rake data_cycle_core:db:clean_up_dumps

echo "### POST MIGRATIONS END ###"

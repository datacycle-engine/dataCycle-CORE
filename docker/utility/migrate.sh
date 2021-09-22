#!/bin/bash
set -e

bundle exec rake data_cycle_core:db:dump

bundle exec rake db:migrate

bundle exec rake data_cycle_core:update:import_classifications
bundle exec rake data_cycle_core:update:import_external_system_configs
bundle exec rake data_cycle_core:refactor:import_update_all_templates

# migrate data after restart
# bundle exec rake db:migrate:with_data

# update computed attribtues
# bundle exec rake dc:update_data:computed_attributes

# cleanup db dumps
#bundle exec rake data_cycle_core:db:clean_up_dumps

echo "WUHU DONE :)"
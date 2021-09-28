#!/bin/bash
set -e

# initialize tasks
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake db:seed
bundle exec rake ${CORE_RAKE_PREFIX}data_cycle_core:update:import_classifications
bundle exec rake ${CORE_RAKE_PREFIX}data_cycle_core:update:import_templates
bundle exec rake ${CORE_RAKE_PREFIX}data_cycle_core:update:import_external_system_configs


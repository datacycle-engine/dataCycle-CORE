#!/bin/bash

set -e

pwd

ls -la

rake -T

bundle exec rake data_cycle_core:update:import_classifications

bundle exec rake data_cycle_core:refactor:import_update_all_templates

echo "wuhu DONE :)"
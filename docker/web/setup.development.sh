#!/bin/bash

gem install bundler

bundle install

(yarn && yarn upgrade) &> log/yarn.log &

# check if db exists
bundle exec rake db:version

if [ $? -eq 0 ]
then
  echo "dataCycle database exists"
else
  echo "dataCycle database does not exists. Initialize database."
  ${DC_DOCKER_SETUP_PATH:-/app/docker/}utility/initialize.sh
fi

set -e

# update project dictionaries if existing in main projects config/configurations/ts_search/
bundle exec rake ${CORE_RAKE_PREFIX:-}dc:update:dictionaries

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app${CORE_DUMMY_PREFIX:-}/tmp/pids/server.pid

RAILS_LOG_TO_STDOUT=true exec bundle exec puma -C ${DC_DOCKER_SETUP_PATH:-/app/docker/}web/puma.rb "$@"

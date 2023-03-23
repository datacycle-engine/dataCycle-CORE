#!/bin/bash

gem install bundler

bundle check || bundle install --jobs $(nproc)

yarn && yarn upgrade
bundle exec vite dev &> log/vite.log &

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

mkdir -p /app${CORE_DUMMY_PREFIX:-}/public/uploads/storage && mkdir -p /app${CORE_DUMMY_PREFIX:-}/public/uploads/processed/video && chown ruby:ruby -R /app${CORE_DUMMY_PREFIX:-}/public/uploads

# create history directory
mkdir -p /app${CORE_DUMMY_PREFIX:-}/docker/hist && chown ruby:ruby -R /app${CORE_DUMMY_PREFIX:-}/docker/hist

# enable warnings
#RUBYOPT='-w' RAILS_LOG_TO_STDOUT=true exec bundle exec puma -p ${PUBLIC_APPLICATION_PORT:-3003} -C ${DC_DOCKER_SETUP_PATH:-/app/docker/}web/puma.rb "$@"
RAILS_LOG_TO_STDOUT=true exec bundle exec puma -p ${PUBLIC_APPLICATION_PORT:-3003} -C ${DC_DOCKER_SETUP_PATH:-/app/docker/}web/puma.rb "$@"

# frozen_string_literal: true

# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# activate for deployment:
server '45.129.181.4', user: 'pixelpoint', roles: ['app', 'db', 'web']
set :branch, 'develop'
set :rails_env, 'staging'
set :deploy_to, '/var/www/data-cycle-core/develop'
set :cmd_prefix, 'app:'
set :application_root_path, 'test/dummy/'
set :server_name, 'core-develop.datacycle.at'
set :deploy_user, 'pixelpoint'
set :appsignal_env, 'develop'

namespace :deploy do
  before 'deploy:migrate', 'datacycle:dev:dump_db'
  after 'deploy:cleanup', 'datacycle:dev:clean_up_dumps'
end

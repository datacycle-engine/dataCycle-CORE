# frozen_string_literal: true

# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# activate for deployment:
server '37.61.206.122', user: 'pixelpoint', roles: ['app', 'db', 'web']
set :branch, 'release'
set :rails_env, 'production'
set :deploy_to, '/var/www/data-cycle-core/production'
set :cmd_prefix, 'app:'
set :application_root_path, 'test/dummy/'
set :server_name, 'feratel-demo.datacycle.at'
set :deploy_user, 'pixelpoint'
set :appsignal_env, 'production'

namespace :deploy do
  before 'deploy:migrate', 'datacycle:dev:dump_db'
  after 'deploy:cleanup', 'datacycle:dev:clean_up_dumps'
end
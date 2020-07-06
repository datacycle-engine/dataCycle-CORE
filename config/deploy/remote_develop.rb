# frozen_string_literal: true

# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

server '45.129.181.4', user: 'pixelpoint', roles: ['app', 'db', 'web']
set :application, 'remote-develop'
set :branch, 'remote-develop'
set :rails_env, 'development'
set :deploy_to, '/var/www/remote-develop'
set :cmd_prefix, 'app:'
set :application_prefix, 'data-cycle-core_'
set :application_root_path, 'test/dummy/'
set :deploy_user, 'pixelpoint'
set :server_name, 'remote-develop.datacycle.at'

append :linked_files, 'config/locales/it.yml', 'config/locales/devise.it.yml'

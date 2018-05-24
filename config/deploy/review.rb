# frozen_string_literal: true

# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

server '37.61.206.122', user: 'pixelpoint', roles: ['app', 'db', 'web']
set :application, ENV.fetch('application', 'data-cycle-core')
set :branch, ENV.fetch('branch', 'master')
set :deploy_to, "/var/www/data-cycle-core/#{ENV.fetch('application', 'development')}"
set :cmd_prefix, 'app:'
set :application_prefix, 'data-cycle-core_'
set :application_root_path, 'test/dummy/'
set :domain_prefix, 'core'
set :domain, 'datacycle.at'

Rake::Task['deploy:create_db'].clear_actions
namespace :deploy do
  task :create_db do
    invoke 'review:create_db'
  end

  before 'deploy:check:linked_files', 'review:copy_files'
end

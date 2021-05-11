# frozen_string_literal: true

# config valid only for current version of Capistrano
# lock "3.8.2"
invoke 'datacycle:default_configs:load'

set :application, 'data-cycle-core'
set :repo_url, 'git@git.pixelpoint.biz:data-cycle/data-cycle-core.git'

set :puma_rackup, -> { File.join(current_path, 'test', 'dummy', 'config.ru') }

# Default value for :linked_files is []
remove :linked_files, '.env'
append :linked_files, 'test/dummy/.env'

# Default value for linked_dirs is []
remove :linked_dirs, 'vendor/gems/data-cycle-core/node_modules'
append :linked_dirs, 'test/dummy/tmp', 'test/dummy/public/uploads', 'test/dummy/public/assets', 'test/dummy/db/backups', 'test/dummy/log'

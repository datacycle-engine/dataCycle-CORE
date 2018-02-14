# config valid only for current version of Capistrano
# lock "3.8.2"

set :application, 'data-cycle-core'
set :repo_url, 'git@git.pixelpoint.biz:data-cycle/data-cycle-core.git'

set :rvm_ruby_version, '2.4.3'

set :puma_rackup, -> { File.join(current_path, 'test', 'dummy', 'config.ru') }

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: 'log/capistrano.log', color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

set :bundle_without, (['development', 'test'] - [fetch(:stage).to_s]).join(' ')

# Default value for :linked_files is []
append :linked_files, 'test/dummy/.env'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'node_modules', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'test/dummy/public/assets'

Rake::Task['deploy:assets:precompile'].clear_actions
Rake::Task['deploy:assets:backup_manifest'].clear_actions

Rake::Task['git:create_release'].clear_actions
namespace :git do
  task :update do
    on roles(:all) do
      with fetch(:git_environmental_variables) do
        within repo_path do
          execute :git, :clone, '-b', fetch(:branch), '--recursive', '.', release_path
        end
      end
    end
  end

  task create_release: :'git:update' do
    on release_roles :all do
      with fetch(:git_environmental_variables) do
        within repo_path do
        end
      end
    end
  end
end

namespace :deploy do
  task :npm do
    on roles(:all) do
      execute "cd #{release_path} && yarn --production"
    end
  end

  task :gulp do
    on roles(:all) do
      execute "cd #{release_path} && ./node_modules/gulp/bin/gulp.js production"
    end
  end

  task :iconfonts do
    on roles(:all) do
      execute "cd #{release_path} && cp -Rf ./lib/assets/fonts/. ./test/dummy/public/assets"
    end
  end

  namespace :assets do
    task :precompile do
      on release_roles(fetch(:assets_roles)) do
        within release_path do
          with rails_env: fetch(:rails_env), rails_groups: fetch(:rails_assets_groups) do
            execute :rake, 'app:assets:precompile'
          end
        end
      end
    end
  end

  desc 'performs initial deploy'
  task :initial do
    before 'deploy:migrate', 'deploy:create_db'
    after 'deploy:migrate', 'deploy:seed'
    invoke 'deploy'
  end

  desc 'runs rails db:create'
  task :create_db do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:create'
        end
      end
    end
  end

  desc 'runs rails db:seed and import classifications and templates'
  task :seed do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:seed'
          execute :rake, 'app:data_cycle_core:update:import_classifications'
          execute :rake, 'app:data_cycle_core:update:import_templates'
        end
      end
    end
  end

  before 'assets:precompile', 'deploy:npm'
  after 'deploy:npm', 'deploy:gulp'
  after 'assets:precompile', 'deploy:iconfonts'

  before 'deploy:reverted', 'deploy:npm'
end

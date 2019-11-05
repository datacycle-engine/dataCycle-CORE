# frozen_string_literal: true

# config valid only for current version of Capistrano
# lock "3.8.2"
invoke 'datacycle:default_configs:load'

set :application, 'data-cycle-core'
set :repo_url, 'git@git.pixelpoint.biz:data-cycle/data-cycle-core.git'

set :puma_rackup, -> { File.join(current_path, 'test', 'dummy', 'config.ru') }

# Default value for :linked_files is []
set :linked_files, 'test/dummy/.env'

# Default value for linked_dirs is []
append :linked_dirs, 'test/dummy/tmp', 'test/dummy/public/uploads', 'test/dummy/public/assets', 'test/dummy/db/backups'

Rake::Task['deploy:npm'].clear_actions
Rake::Task['deploy:gulp'].clear_actions
Rake::Task['deploy:iconfonts'].clear_actions
Rake::Task['deploy:assets:precompile'].clear_actions
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
end

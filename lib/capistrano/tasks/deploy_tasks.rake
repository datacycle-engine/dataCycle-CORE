# frozen_string_literal: true

namespace :deploy do
  task :npm do
    on roles(:all) do
      execute "cd #{release_path}/vendor/gems/data-cycle-core/ && yarn --production"
      execute "cd #{release_path} && yarn --production"
    end
  end

  task :gulp do
    on roles(:all) do
      execute "cd #{release_path}/vendor/gems/data-cycle-core/ && ./node_modules/gulp/bin/gulp.js production"
      execute "cd #{release_path} && ./node_modules/gulp/bin/gulp.js production"
    end
  end

  task :iconfonts do
    on roles(:all) do
      execute "cd #{release_path} && cp -Rf ./lib/assets/fonts/. ./public/assets"
    end
  end

  desc 'performs initial deployment'
  task :initial do
    before 'deploy:migrate', 'deploy:create_db'
    after 'deploy:migrate', 'deploy:seed'
    invoke 'deploy'
  end

  desc 'runs rake db:create'
  task :create_db do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:create'
        end
      end
    end
  end

  desc 'runs rake db:seed and import classifications and templates'
  task :seed do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:seed'
          execute :rake, 'data_cycle_core:update:import_classifications'
          execute :rake, 'data_cycle_core:update:import_templates'
        end
      end
    end
  end
end
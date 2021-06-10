# frozen_string_literal: true

namespace :deploy do
  task :psql do
    on roles(:all) do
      invoke 'datacycle:psql:deploy_dict'
      invoke 'datacycle:psql:reload'
    end
  end

  task :load_dict do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "#{fetch(:cmd_prefix, '')}dc:update:dictionaries"
        end
      end
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
          execute :rake, "#{fetch(:cmd_prefix, '')}db:create"
        end
      end
    end
  end

  desc 'runs rake db:seed and import classifications and templates, updates dictionaries'
  task :seed do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "#{fetch(:cmd_prefix, '')}db:seed"
          execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:update:import_classifications"
          execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:update:import_templates"
        end
      end
    end
  end

  desc 'runs data migrations'
  task :data_migrations do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "#{fetch(:cmd_prefix, '')}db:migrate:with_data"
        end
      end
    end
  end
end

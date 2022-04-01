# frozen_string_literal: true

namespace :datacycle do
  namespace :default_configs do
    desc 'load default configurations from core'
    task :load do
      set :rvm_ruby_version, '2.7.4'
      set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }
      set :deploy_user, 'pixelpoint'

      set :delayed_job_pools, {
        'mailers' => 1,
        'importers' => 1,
        'carrierwave' => 1,
        'cache_invalidation' => 2,
        'search_update' => 3,
        'webhooks' => 1,
        'default' => 1
      }

      set :bundle_without, (['development', 'test'] - [fetch(:stage).to_s]).join(' ')

      append :linked_files, '.env'
      append :linked_dirs, 'log', 'db/backups', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'public/uploads', 'public/eyebase', 'public/filmcommission', 'public/downloads'

      namespace :deploy do
        after 'deploy:started', :add_special_tasks do
          after 'puma:restart', 'deploy:data_migrations'
          before 'puma:restart', 'datacycle:puma:deploy_config' unless fetch(:skip_deploy_configs)
        end

        after 'delayed_job:restart', 'deploy:unlock_jobs'
        after 'bundler:install', 'deploy:assets:precompile'
        after 'bundler:install', 'datacycle:psql:deploy_dict'
        after 'deploy:migrate', 'datacycle:dev:update_project'
        after 'datacycle:dev:update_project', 'datacycle:dev:migrate_project'
        after 'deploy:cleanup', 'datacycle:dev:update_configs' unless fetch(:skip_deploy_configs)
      end
    end
  end
end

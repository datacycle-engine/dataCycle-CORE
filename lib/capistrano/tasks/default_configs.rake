# frozen_string_literal: true

namespace :datacycle do
  namespace :default_configs do
    desc 'load default configurations from core'
    task :load do
      set :rvm_ruby_version, '2.7.1'
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

      set :default_env, { SKIP_POST_DEPLOYMENT_MIGRATIONS: true }

      set :bundle_without, (['development', 'test'] - [fetch(:stage).to_s]).join(' ')

      append :linked_files, '.env', 'public/assets/build/manifest.json', 'public/assets/build/manifest-assets.json'
      append :linked_dirs, 'log', 'db/backups', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'public/uploads', 'public/eyebase', 'public/filmcommission'

      namespace :deploy do
        after 'deploy:started', :add_special_tasks do
          after 'puma:restart', 'deploy:post_deploy_migrations'
          before 'puma:restart', 'datacycle:puma:deploy_config' unless fetch(:skip_deploy_configs)
        end

        # before 'assets:precompile', 'deploy:npm'
        # after 'deploy:npm', 'deploy:gulp'
        # after 'assets:precompile', 'deploy:iconfonts'
        after 'bundler:install', 'deploy:assets:precompile'

        before 'deploy:migrate', 'deploy:psql'
        after 'deploy:psql', 'deploy:load_dict'
        after 'deploy:migrate', 'datacycle:dev:update_project'
        after 'datacycle:dev:update_project', 'datacycle:dev:migrate_project'
        after 'deploy:cleanup', 'datacycle:dev:update_configs' unless fetch(:skip_deploy_configs)

        before 'deploy:reverted', 'deploy:assets:precompile'
      end
    end
  end
end

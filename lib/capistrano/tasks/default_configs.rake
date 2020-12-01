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
        'cache_invalidation' => 3,
        'search_update' => 3,
        'webhooks' => 1,
        'default' => 1
      }

      set :bundle_without, (['development', 'test'] - [fetch(:stage).to_s]).join(' ')

      append :linked_files, '.env'
      append :linked_dirs, 'node_modules', 'vendor/gems/data-cycle-core/node_modules', 'log', 'db/backups', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'public/uploads', 'public/eyebase', 'public/filmcommission'

      namespace :deploy do
        after 'deploy:started', :add_special_tasks do
          after 'puma:restart', 'datacycle:dev:migrate_project_with_new_configs'
          before 'puma:restart', 'datacycle:puma:deploy_config' unless fetch(:skip_deploy_configs)
        end

        before 'assets:precompile', 'deploy:npm'
        after 'deploy:npm', 'deploy:gulp'
        after 'assets:precompile', 'deploy:iconfonts'

        after 'deploy:migrate', 'datacycle:dev:update_project'
        after 'datacycle:dev:update_project', 'datacycle:dev:migrate_project'
        after 'deploy:cleanup', 'datacycle:dev:update_configs' unless fetch(:skip_deploy_configs)

        before 'deploy:reverted', 'deploy:npm'
      end
    end
  end
end

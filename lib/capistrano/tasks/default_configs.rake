# frozen_string_literal: true

namespace :datacycle do
  namespace :default_configs do
    desc 'load default configurations from core'
    task :load do
      set :rvm_ruby_version, '2.6.3'
      set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }

      set :puma_workers, 1
      set :puma_worker_killer, true

      set :delayed_job_pools, {
        'mailers' => 1,
        'importers' => 1,
        'carrierwave' => 1,
        'cache_invalidation,search_update' => 1,
        'webhooks' => 1,
        'default' => 1
      }

      set :bundle_without, (['development', 'test'] - [fetch(:stage).to_s]).join(' ')

      append :linked_files, '.env'
      append :linked_dirs, 'node_modules', 'vendor/gems/data-cycle-core/node_modules', 'log', 'db/backups', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'public/uploads'

      namespace :deploy do
        before 'assets:precompile', 'deploy:npm'
        after 'deploy:npm', 'deploy:gulp'
        after 'assets:precompile', 'deploy:iconfonts'

        after 'deploy:migrate', 'datacycle:dev:update_project'

        before 'deploy:reverted', 'deploy:npm'
      end
    end
  end
end
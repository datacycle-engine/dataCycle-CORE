# frozen_string_literal: true

namespace :review do
  task :create_db do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:version'
          execute :rake, 'db:create'
        rescue StandardError
          execute :rake, 'db:create'
          # invoke 'review:init_dev_db'
        end
      end
    end
  end

  desc 'undeploy review app'
  task :undeploy do
    on roles(:all) do
      invoke 'delayed_job:stop'
      invoke 'puma:stop'
      # delete database
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:db:clear_connections"
          execute :rake, 'db:drop'
        rescue StandardError
          print_message 'ERROR: Unable to DELETE database'
        end
      end
      execute "rm -rf #{fetch(:deploy_to)}"
    end
  end

  desc 'copy required review app files'
  task :copy_files do
    on roles(:all) do
      within shared_path do
        with rails_env: fetch(:rails_env) do
          test_path = shared_path.join('.env')
          print_message "test_path: #{test_path}"
          unless test("[ -f #{test_path} ]")
            run_locally do
              command = "#{fetch(:cmd_prefix, '')}data_cycle_core:review_app:init[#{fetch(:application_prefix, '')}#{fetch(:application)}, #{fetch(:domain_prefix)}-#{fetch(:application)}.#{fetch(:domain)}]"
              `bundle exec rake "#{command}"`
            end
            upload! "#{fetch(:application_root_path, '')}tmp/.env", "#{fetch(:application_root_path, '')}.env"
            print_message 'required files created'
          end
        end
      end
    end
  end

  # desc 'init dev db'
  # task :init_dev_db do
  #   run_locally do
  #     `cap develop review:download_dev_db`
  #   end
  #   invoke 'review:upload_dev_db'
  # end

  # desc 'download dev db'
  # task :download_dev_db, [:history] do |_, args|
  #   on roles(:db) do
  #     within release_path do
  #       with rails_env: fetch(:rails_env) do
  #         if args[:history] == 'true'
  #           execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:db:dump[dev_db,dump,full]"
  #         else
  #           execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:db:dump[dev_db,dump,review]"
  #         end
  #       end
  #     end
  #     within shared_path do
  #       download! "#{fetch(:application_root_path, '')}db/backups/#{fetch(:rails_env, 'staging')}/dev_db.dump", "#{fetch(:application_root_path, '')}tmp/dev_db.dump"
  #     end
  #     print_message 'dev database: download complete'
  #   end
  # end

  # desc 'upload dev db'
  # task :upload_dev_db do
  #   on roles(:app) do
  #     # upload database
  #     within shared_path do
  #       upload! "#{fetch(:application_root_path, '')}tmp/dev_db.dump", "#{fetch(:application_root_path, '')}db/backups/dev_db.dump"
  #     end
  #     within release_path do
  #       with rails_env: fetch(:rails_env) do
  #         execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:db:restore[dev_db]"
  #       end
  #     end
  #     print_message 'dev database: upload complete'
  #   end
  # end
end

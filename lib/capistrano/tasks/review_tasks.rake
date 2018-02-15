namespace :review do
  task :create_db do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          begin
            execute :rake, 'db:version'
            execute :rake, 'db:create'
          rescue StandardError
            execute :rake, 'db:create'
            invoke 'review:init_staging_db'
          end
        end
      end
    end
  end

  desc 'undeploy review app'
  task :undeploy do
    on roles(:all) do
      invoke 'puma:stop'
      # TODO: delete database
      # within release_path do
      #   with rails_env: fetch(:rails_env) do
      #     begin
      #       execute :rake, 'db:drop'
      #     rescue StandardError
      #       print_message 'ERROR: Unable to DELETE database'
      #     end
      #   end
      # end
      execute "rm -rf #{fetch(:deploy_to)}"
    end
  end

  desc 'copy required review app files'
  task :copy_files do
    on roles(:all) do
      within shared_path do
        with rails_env: fetch(:rails_env) do
          test_path = shared_path.join('.env')
          unless test("[ -f #{test_path} ]")
            run_locally do
              command = "data_cycle_core:review_app:init[#{fetch(:application)}]"
              `bundle exec rake "#{command}"`
            end
            upload! 'tmp/.env', '.env'
            print_message 'required files created'
          end
        end
      end
    end
  end

  desc 'init staging db'
  task :init_staging_db do
    run_locally do
      `cap staging review:download_staging_db`
    end
    invoke 'review:upload_staging_db'
  end

  desc 'download staging db'
  task :download_staging_db do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'data_cycle_core:db:dump[staging_db,sql]'
        end
      end
      within shared_path do
        download! 'db/backups/staging/staging_db.sql', 'tmp/staging_db.sql'
      end
      print_message 'staging database: download complete'
    end
  end

  desc 'upload staging db'
  task :upload_staging_db do
    on roles(:app) do
      # upload database
      within shared_path do
        upload! 'tmp/staging_db.sql', 'db/backups/staging_db.sql'
      end
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'data_cycle_core:db:restore[staging_db]'
        end
      end
      print_message 'staging database: upload complete'
    end
  end

  private

  def print_message(msg)
    puts ''
    puts "############### #{msg}"
    puts ''
  end
end

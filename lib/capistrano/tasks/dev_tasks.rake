# frozen_string_literal: true

namespace :datacycle do
  namespace :dev do
    desc 'update project: dump database - update all templates + external sources'
    task :update_project do
      on roles(:all) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            print_message 'Update Project'
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:refactor:import_update_all_templates" unless fetch(:skip_template_import, false)
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:update:import_external_system_configs" unless fetch(:skip_external_system_import, false)
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:update:import_classifications" unless fetch(:skip_classification_import, false)
          end
        end
      end
    end

    desc 'dump database'
    task :dump_db do
      on roles(:all) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            print_message 'Dump Database'
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:db:dump"
          end
        end
      end
    end

    desc 'clean up database dumps'
    task :clean_up_dumps do
      on roles(:all) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            print_message 'Clean up database dumps'
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:db:clean_up_dumps"
          end
        end
      end
    end

    desc 'update project config files before 5_2_3 deployment'
    task :update_configs_before_deploy do
      on roles(:all) do
        print_message 'Update puma config'
        invoke 'datacycle:puma:deploy_config'

        print_message 'Uploading config files'
        invoke 'datacycle:logrotate:deploy_config'
      end
    end

    desc 'update project config files: update monit + puma'
    task :update_configs do
      on roles(:all) do
        # print_message 'Update puma config'
        # invoke 'datacycle:puma:deploy_config'
        # invoke 'datacycle:puma:restart'

        print_message 'Uploading config files'
        invoke('datacycle:monit:deploy_config', 'puma.conf')
        invoke!('datacycle:monit:deploy_config', 'delayed_job.conf')
        # invoke 'datacycle:logrotate:deploy_config'

        print_message 'Reloading services'
        invoke 'datacycle:monit:reload'

        # invoke('datacycle:nginx:deploy_config', 'production.conf')
        # invoke 'datacycle:nginx:reload'
        # invoke 'datacycle:duplicity:deploy_config'
      end
    end

    desc 'initialize new project'
    task :init_project do
      on roles(:all) do
        print_message 'deploy check'
        invoke 'deploy:check'

        print_message 'init .env'
        invoke 'datacycle:init_env'

        print_message 'init configs'
        invoke 'datacycle:init_configs'

        print_message 'deploy new project'
        invoke 'deploy:initial'
      end
    end

    desc 'initialize configs'
    task :init_configs do
      on roles(:all) do
        print_message 'Update puma config'
        invoke 'datacycle:puma:deploy_config'
        invoke 'datacycle:puma:restart'

        print_message 'Uploading config files'
        invoke('datacycle:monit:deploy_config', 'puma.conf')
        invoke!('datacycle:monit:deploy_config', 'delayed_job.conf')
        invoke 'datacycle:logrotate:deploy_config'

        print_message 'Reloading services'
        invoke 'datacycle:monit:reload'

        invoke('datacycle:nginx:deploy_config', 'production.conf')
        invoke 'datacycle:nginx:reload'
        invoke 'datacycle:duplicity:deploy_config'
      end
    end

    desc 'init env'
    task :init_env do
      on roles(:all) do
        within shared_path do
          with rails_env: fetch(:rails_env) do
            test_path = shared_path.join('.env')
            print_message "test_path: #{test_path}"
            unless test("[ -f #{test_path} ]")
              print_message 'Enter db password'
              run_locally do
                command = "#{fetch(:cmd_prefix, '')}dc:local_dev:init_env[#{fetch(:application)}, #{fetch(:server_name)}]"
                `bundle exec rake "#{command}"`
              end
              upload! "#{fetch(:application_root_path, '')}tmp/.env", "#{fetch(:application_root_path, '')}.env"
              print_message 'env file create and uploaded'
            end
          end
        end
      end
    end

    desc 'update project config files: update monit + nginx config files'
    task :configs_exists do
      on roles(:all) do
        print_message 'checking for config files'
        invoke 'datacycle:logrotate:validate_config'
        invoke 'datacycle:monit:validate_config'

        # invoke 'datacycle:nginx:validate_config'
        # invoke 'datacycle:duplicity:validate_config'
      end
    end

    private

    def print_message(msg)
      puts ''
      puts "############### #{msg}"
      puts ''
    end

    def remote_config_file_exists(target_file_name, task_name)
      on roles(:all) do
        with rails_env: fetch(:rails_env) do
          if test("[ -f #{target_file_name} ]")
            puts "### #{task_name} config file exist: #{target_file_name}"
          else
            puts "### #{task_name} config file does not exist: #{target_file_name}"
          end
        end
      end
    end
  end
end

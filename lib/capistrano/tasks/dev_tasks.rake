# frozen_string_literal: true

namespace :datacycle do
  namespace :dev do
    desc 'update project: dump database - update all templates + external sources'
    task :update_project do
      on roles(:all) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            print_message 'Update Project'
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:refactor:import_update_all_templates"
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:update:import_external_source_configs"
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

    desc 'update project config files: update monit + nginx config files'
    task :update_configs do
      on roles(:all) do
        print_message 'Uploading config files'
        invoke('datacycle:monit:deploy_config', 'puma.conf')
        invoke!('datacycle:monit:deploy_config', 'delayed_job.conf')
        # invoke('datacycle:nginx:deploy_config', 'production.conf')
        invoke 'datacycle:logrotate:deploy_config'

        print_message 'Update puma config'
        invoke 'datacycle:puma:deploy_config'
        invoke 'datacycle:puma:restart'

        print_message 'Reloading services'
        # invoke 'datacycle:nginx:reload'
        invoke 'datacycle:monit:reload'
      end
    end

    desc 'update project config files: update monit + nginx config files'
    task :configs_exists do
      on roles(:all) do
        print_message 'checking for config files'
        file_paths = ['/tmp/my_awesome_test/wuhu.txt']
        file_paths.each do | file_path |
          unless test("[ -f #{file_path} ]")
            puts "### config file does not exists: #{file_path}"
          end
        end
      end
    end
  end
end

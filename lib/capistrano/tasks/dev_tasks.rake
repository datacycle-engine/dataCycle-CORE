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

    desc 'migrates project via rake task'
    task :migrate_project do
      on roles(:all) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            print_message 'Migrating Project'
            print_message 'No pending migrations found'
            # execute :rake, "#{fetch(:cmd_prefix, '')}dc:update_data:computed_attributes[false,true,\"headline\\,name\\,legal_name\"]"
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

    desc 'update project config files: update monit + puma'
    task :update_configs do
      on roles(:all) do
        # update puma config must be invoked in another task
        # see: datacycle:default_configs:deploy
        # print_message 'Update puma config'
        # invoke 'datacycle:puma:deploy_config'
        # invoke 'datacycle:puma:restart'

        print_message 'Uploading monit config files'
        invoke('datacycle:monit:deploy_config', 'puma.conf')
        invoke!('datacycle:monit:deploy_config', 'delayed_job.conf')

        # print_message 'Uploading logrotate config files'
        # invoke 'datacycle:logrotate:deploy_config'

        print_message 'Reloading services'
        invoke 'datacycle:monit:reload'

        print_message 'Upload proxmox backup exclude file'
        invoke 'datacycle:proxmox:deploy_config'

        # invoke('datacycle:nginx:deploy_config', 'production.conf')
        # invoke 'datacycle:nginx:reload'

        # print_message 'Uploading duplicity config files'
        # invoke 'datacycle:duplicity:deploy_config'
      end
    end

    desc 'initialize new project'
    task :init_project do
      on roles(:all) do
        print_message 'deploy:check directories'
        invoke 'deploy:check:directories'
        invoke 'deploy:check:linked_dirs'

        print_message 'init .env'
        invoke 'datacycle:dev:init_env'

        print_message 'deploy:check'
        invoke 'deploy:check'

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

        # print_message 'Uploading logrotate config files'
        invoke 'datacycle:logrotate:deploy_config'

        print_message 'Reloading services'
        invoke 'datacycle:monit:reload'

        invoke('datacycle:nginx:deploy_config', 'production.conf')
        invoke 'datacycle:nginx:reload'

        # print_message 'Uploading duplicity config files'
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

    desc 'check if config files exists'
    task :configs_exists do
      on roles(:all) do
        print_message 'checking for config files'
        invoke 'datacycle:logrotate:validate_config'
        invoke 'datacycle:monit:validate_config'

        invoke 'datacycle:nginx:validate_config'
        invoke 'datacycle:duplicity:validate_config'
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

namespace :dc do
  namespace :dev do
    SSHKit.config.command_map[:dc_mkdir] = 'mkdir -p'
    SSHKit.config.command_map[:dc_rm] = 'rm -r'
    SSHKit.config.command_map[:dc_rm_file] = 'rm'
    SSHKit.config.command_map[:dc_rake_local] = 'bundle exec rake'
    SSHKit.config.command_map[:dc_rsync] = 'rsync -avr'

    desc 'import remote mongo db'
    task :import_remote_mongo, [:external_system_id, :port] do |_, args|
      local_rails_env = ENV.fetch('RAILS_ENV', 'development')
      remote_file_name = nil

      on roles(:all) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:mongo:dump[#{args[:external_system_id]},true]"
            remote_file_name = capture(:ls, "#{fetch(:application_root_path, '')}db/backups/#{fetch(:rails_env, 'staging')}/mongo/download/*_#{args[:external_system_id]}_download.archive")
          end
        end
        puts shared_path
        puts remote_file_name
        puts "#{fetch(:application_root_path, '')}tmp/"
        within shared_path do
          download! remote_file_name, "#{fetch(:application_root_path, '')}tmp/"
        end
        print_message 'download complete'

        print_message remote_file_name

        within release_path do
          execute "rm #{release_path}/#{remote_file_name}"
        end
      end

      file_name = remote_file_name.split('/').last

      run_locally do
        with rails_env: local_rails_env do
          execute :dc_mkdir, "db/backups/#{local_rails_env}/mongo/download"
          execute :dc_rsync, "tmp/#{file_name} db/backups/#{local_rails_env}/mongo/download"
          execute :dc_rm_file, "tmp/#{file_name}"
          execute :dc_rake_local, "'#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:mongo:dump[#{args[:external_system_id]},true]' RAILS_ENV=#{local_rails_env}" if local_rails_env != 'development'
          execute :dc_rake_local, "'#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:mongo:restore[#{file_name},true,#{args[:port] || '27017'}]' RAILS_ENV=#{local_rails_env}"
        end
      end

      puts "Successfully imported mongo DB #{file_name} from #{fetch(:rails_env)}"
    end

    desc 'import remote db (mode = review|activities|full)'
    task :import_remote_db, [:mode, :format] do |_, args|
      dump_format = ensure_format(args.format)
      mode = args.mode || 'review'
      dump_suffix = suffix_for_format(dump_format)
      local_rails_env = ENV.fetch('RAILS_ENV', 'development')

      on roles(:all) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:db:dump[dev_db,#{dump_format},#{mode}]"
          end
        end

        within shared_path do
          download! "#{fetch(:application_root_path, '')}db/backups/#{fetch(:rails_env, 'staging')}/dev_db.#{dump_suffix}", "#{fetch(:application_root_path, '')}tmp/", recursive: true
        end

        run_locally do
          with rails_env: local_rails_env do
            execute :dc_mkdir, "db/backups/#{local_rails_env}/"
            execute :dc_rsync, "tmp/dev_db.#{dump_suffix} db/backups/#{local_rails_env}/"
            execute :dc_rm, "tmp/dev_db.#{dump_suffix}"
            execute :dc_rake_local, "#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:db:dump RAILS_ENV=#{local_rails_env}" if local_rails_env != 'development'
            execute :dc_rake_local, "#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:db:restore[dev_db.#{dump_suffix}] RAILS_ENV=#{local_rails_env}"

            if local_rails_env != 'development'
              execute :dc_rake_local, "#{ENV['CORE_RAKE_PREFIX']}db:migrate RAILS_ENV=#{local_rails_env}"
              execute :dc_rake_local, "#{ENV['CORE_RAKE_PREFIX']}dc:update:configs[true] RAILS_ENV=#{local_rails_env}"
            end
          end
        end

        puts "Successfully imported DB from #{fetch(:rails_env)}"
      end
    end

    private

    def ensure_format(format)
      return format if ['c', 'p', 't', 'd'].include?(format)

      case format
      when 'dump' then 'c'
      when 'sql' then 'p'
      when 'tar' then 't'
      when 'dir' then 'd'
      else 'd'
      end
    end

    def suffix_for_format(suffix)
      case suffix
      when 'c' then 'dump'
      when 'p' then 'sql'
      when 't' then 'tar'
      when 'd' then 'dir'
      end
    end
  end
end

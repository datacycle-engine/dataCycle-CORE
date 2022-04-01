# frozen_string_literal: true

SSHKit.config.command_map[:sudo_mkdir] = 'sudo mkdir -p'
SSHKit.config.command_map[:sudo_cp] = 'sudo cp'

namespace :datacycle do
  namespace :psql do
    desc 'copy thesaurus data for postgresql server'
    task :deploy_dict do
      on roles(:db) do
        dictionaries_exist = false

        within release_path do
          with rails_env: fetch(:rails_env) do
            source_path = release_path.join('config/configurations/ts_search/*.ths')
            target_path = "/usr/share/postgresql/#{ENV.fetch('POSTGRES_VERSION', '11')}/tsearch_data/"

            if test("[ -f #{source_path} ]")
              dictionaries_exist = true
              execute :sudo_mkdir, "/usr/share/postgresql/#{ENV.fetch('POSTGRES_VERSION', '11')}/tsearch_data/" unless test("[ -d #{target_path} ]")
              execute :sudo_cp, "#{source_path} /usr/share/postgresql/#{ENV.fetch('POSTGRES_VERSION', '11')}/tsearch_data/"
            end
          end
        end

        if dictionaries_exist
          invoke 'datacycle:psql:reload'

          within release_path do
            with rails_env: fetch(:rails_env) do
              execute :rake, "#{fetch(:cmd_prefix, '')}dc:update:dictionaries"
            end
          end
        end
      end
    end

    desc 'restart psql'
    task :reload do
      on roles(:db) do
        execute 'sudo systemctl restart postgresql'
      end
    end
  end
end

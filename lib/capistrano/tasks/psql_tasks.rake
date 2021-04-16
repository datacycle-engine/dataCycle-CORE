# frozen_string_literal: true

namespace :datacycle do
  namespace :psql do
    desc 'copy thesaurus data for postgresql server'
    task :deploy_dict do
      on roles(:all) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            source_path = release_path.join('config/configurations/ts_search/*.ths')
            target_path = "/usr/share/postgresql/#{ENV.fetch('POSTGRES_VERSION', '11')}/tsearch_data/"
            print_message "check for files: #{source_path}"
            if test("[ -f #{source_path} ]")
              print_message 'files exist'
              execute "sudo mkdir -p /usr/share/postgresql/#{ENV.fetch('POSTGRES_VERSION', '11')}/tsearch_data/" unless test("[ -d #{target_path} ]")
              execute "sudo cp #{source_path} /usr/share/postgresql/#{ENV.fetch('POSTGRES_VERSION', '11')}/tsearch_data/"
            end
          end
        end
      end
    end

    desc 'restart psql'
    task :reload do
      on roles(:all) do
        execute 'sudo systemctl restart postgresql'
      end
    end
  end
end

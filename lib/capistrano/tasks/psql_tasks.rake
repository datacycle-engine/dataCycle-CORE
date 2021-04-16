# frozen_string_literal: true

namespace :datacycle do
  namespace :psql do
    desc 'copy thesaurus data for postgresql server'
    task :deploy_dict do
      on roles(:all) do
        with rails_env: fetch(:rails_env) do
          files = Dir.pwd + '/config/configuration/ts_search/*.ths'
          execute "sudo mv #{files} /usr/share/postgresql/#{ENV.fetch('POSTGRES_VERSION', '11')}/tsearch/" if File.exist?(files)
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

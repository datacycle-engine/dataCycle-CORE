# frozen_string_literal: true

SSHKit.config.command_map[:vite_local] = 'bundle exec vite'
SSHKit.config.command_map[:yarn_local] = 'yarn'

namespace :deploy do
  namespace :assets do
    desc 'precompile assets'
    task :precompile do
      on roles(:web) do
        run_locally do
          with rails_env: fetch(:rails_env) do
            execute :yarn_local
            execute :yarn_local, 'upgrade data-cycle-core'
            execute :vite_local, 'build -f'
          end
        end
      end

      on roles(:web) do |server|
        `rsync -avr --exclude='.DS_Store' --relative ./public/assets/build/ #{server.user}@#{server.hostname}:#{release_path}`
        `rsync -avr --exclude='.DS_Store' --relative ./public/assets/fonts/ #{server.user}@#{server.hostname}:#{release_path}`
      end

      `RAILS_ENV=#{fetch(:rails_env)} bundle exec vite clobber`
    end

    # desc 'remove old assets'
    # task :clean do
    #   on roles(:web) do
    #     within release_path do
    #       with rails_env: fetch(:rails_env) do
    #         execute :bundle, 'exec vite clean'
    #       end
    #     end
    #   end
    # end
  end
end

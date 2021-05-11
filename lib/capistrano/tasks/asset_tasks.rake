# frozen_string_literal: true

SSHKit.config.command_map[:vite_local] = 'bundle exec vite'
SSHKit.config.command_map[:npm_local] = 'npm'

namespace :deploy do
  namespace :assets do
    desc 'precompile assets'
    task :precompile do
      on roles(:web) do
        run_locally do
          with rails_env: fetch(:rails_env) do
            execute :npm_local, 'install'
            execute :npm_local, 'update data-cycle-core'
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
  end
end

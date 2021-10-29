# frozen_string_literal: true

SSHKit.config.command_map[:vite_local] = 'bundle exec vite'
SSHKit.config.command_map[:yarn_local] = 'yarn'
SSHKit.config.command_map[:dc_rsync_relative] = "rsync -avr --exclude='.DS_Store' --relative"

namespace :deploy do
  namespace :assets do
    desc 'precompile assets'
    task :precompile do
      on roles(:web) do |server|
        run_locally do
          with rails_env: fetch(:rails_env) do
            execute :yarn_local
            execute :yarn_local, 'upgrade'
            execute :vite_local, 'build -f'
            execute :dc_rsync_relative, "./public/assets/build/ #{server.user}@#{server.hostname}:#{release_path}"
            execute :dc_rsync_relative, "./public/assets/fonts/ #{server.user}@#{server.hostname}:#{release_path}"
            execute :vite_local, 'clobber'
          end
        end
      end
    end
  end
end

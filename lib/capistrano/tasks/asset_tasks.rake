# frozen_string_literal: true

namespace :deploy do
  namespace :assets do
    desc 'precompile assets'
    task :precompile do
      sh "RAILS_ENV=#{fetch(:rails_env, 'production')} bundle exec vite build -f"

      on roles(:web) do |server|
        `rsync -avr --exclude='.DS_Store' ./public/assets/build/ #{server.user}@#{server.hostname}:#{shared_path}/public/assets/build/`
        `rsync -avr --exclude='.DS_Store' ./public/assets/fonts/ #{server.user}@#{server.hostname}:#{shared_path}/public/assets/fonts/`
      end

      sh "RAILS_ENV=#{fetch(:rails_env, 'production')} bundle exec vite clobber"
    end

    desc 'remove old assets'
    task :clean do
      on roles(:web) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :rake, "#{fetch(:cmd_prefix, '')}vite:clean"
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'capistrano/puma'

namespace :datacycle do
  namespace :puma do
    desc 'Generate and push the puma config file for the application'
    task :deploy_config do
      include Capistrano::PumaCommon
      on roles(fetch(:puma_role)) do
        with rails_env: fetch(:rails_env) do
          secret_yaml_file = File.join(Dir.pwd, fetch(:application_root_path, ''), 'config', 'secrets.yml')
          secrets = YAML.safe_load(File.open(secret_yaml_file), [Symbol])
          set :puma_max_threads, secrets.dig(fetch(:rails_env).to_s, 'puma_max_threads') || 5
          set :puma_max_workers, secrets.dig(fetch(:rails_env).to_s, 'puma_max_workers') || 3
          set :puma_max_memory, secrets.dig(fetch(:rails_env).to_s, 'puma_max_memory') || 4096
          set :puma_worker_frequency, secrets.dig(fetch(:rails_env).to_s, 'puma_worker_frequency') || 3600
          set :puma_rolling_restart_frequency, secrets.dig(fetch(:rails_env).to_s, 'puma_rolling_restart_frequency') || false

          template_name = 'puma.rb'
          core_file_path = File.join(Dir.pwd, 'vendor', 'gems', 'data-cycle-core', 'config', 'deploy', 'templates', 'puma', "#{template_name}.erb")
          core_file_path = File.join(Dir.pwd, 'config', 'deploy', 'templates', 'puma', "#{template_name}.erb") unless fetch(:cmd_prefix).nil?
          file_path = File.join(Dir.pwd, fetch(:application_root_path, ''), 'config', 'deploy', 'templates', 'puma', "#{template_name}.erb")

          if File.exist?(file_path)
            template = ERB.new(File.new(file_path).read).result(binding)
          else
            template = ERB.new(File.new(core_file_path).read).result(binding)
          end
          target_file_name = template_name
          within shared_path do
            upload! StringIO.new(template), target_file_name
          end
        end
      end
    end

    desc 'Restart Puma'
    task :restart do
      on roles(fetch(:puma_role)) do
        invoke! 'puma:restart'
      end
    end

    def puma_plugins
      Array(fetch(:puma_plugins)).collect { |bind|
        "plugin '#{bind}'"
      }.join("\n")
    end
  end
end

namespace :puma do
  Rake::Task['puma:check'].clear
  task :check do
    on roles(fetch(:puma_role)) do |_role|
      # Create puma.rb for new deployments
      unless test "[ -f #{fetch(:puma_conf)} ]"
        warn 'puma.rb NOT FOUND!'
        invoke 'datacycle:puma:deploy_config'
        info 'puma.rb generated'
      end
    end
  end
end

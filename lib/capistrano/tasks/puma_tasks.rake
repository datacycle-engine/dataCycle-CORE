# frozen_string_literal: true

require 'capistrano/puma'

namespace :datacycle do
  namespace :puma do
    desc 'Generate and push the puma config file for the application'
    task :deploy_config do
      include Capistrano::PumaCommon
      on roles(fetch(:puma_role)) do
        with rails_env: fetch(:rails_env) do
          secret_yaml_file = Dir.pwd + '/config/secrets.yml'
          secrets = YAML.safe_load(File.open(secret_yaml_file), [Symbol])
          rails_max_threads = secrets.dig(fetch(:rails_env), 'rails_max_threads') || 5
          rails_max_workers = secrets.dig(fetch(:rails_env), 'rails_max_workers') || 0
          set :rails_max_threads, rails_max_threads
          set :rails_max_workers, rails_max_workers

          template_name = 'puma.rb'
          core_file_path = Dir.pwd + "/vendor/gems/data-cycle-core/config/deploy/templates/#{template_name}.erb"
          file_path = Dir.pwd + "/config/deploy/templates/#{template_name}.erb"
          if File.exist?(file_path)
            template = ERB.new(File.new(file_path).read).result(binding)
          else
            template = ERB.new(File.new(core_file_path).read).result(binding)
          end
          target_file_name = template_name
          within shared_path do
            upload! StringIO.new(template), "#{fetch(:application_root_path, '')}#{target_file_name}"
          end
        end
      end
    end

    desc 'Restart Puma'
    task :restart do
      on roles(fetch(:puma_role)) do
        invoke 'puma:restart'
      end
    end

    private

    def print_message(msg)
      puts ''
      puts "############### #{msg}"
      puts ''
    end
  end
end

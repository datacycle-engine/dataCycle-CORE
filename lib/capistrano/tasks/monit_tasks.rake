# frozen_string_literal: true

namespace :datacycle do
  namespace :monit do
    desc 'Generate and push the monit config file for the application'
    task :deploy_config, [:template_name] do |_, args|
      on roles(:all) do
        with rails_env: fetch(:rails_env) do
          template_name = args[:template_name]
          core_file_path = Dir.pwd + "/vendor/gems/data-cycle-core/config/deploy/templates/monit/#{template_name}.erb"
          file_path = Dir.pwd + "/config/deploy/templates/monit/#{template_name}.erb"
          if File.exist?(file_path)
            template = ERB.new(File.new(file_path).read).result(binding)
          else
            template = ERB.new(File.new(core_file_path).read).result(binding)
          end
          target_file_name = "#{fetch(:application)}-#{template_name}"
          upload! StringIO.new(template), "/tmp/#{target_file_name}"
          execute "sudo mv /tmp/#{target_file_name} /etc/monit/conf.d/#{target_file_name}"
        end
      end
    end

    desc 'Reload monit to see all the jobs'
    task :reload do
      on roles(:all) do
        execute 'sudo monit reload', raise_on_non_zero_exit: false
      end
    end

    desc 'validate the monit config files for the application'
    task :validate_config do
      on roles(:all) do
        with rails_env: fetch(:rails_env) do
          ['delayed_job.conf', 'puma.conf'].each do |template_name|
            target_file_name = "/etc/monit/conf.d/#{fetch(:application)}-#{template_name}"
            remote_config_file_exists(target_file_name, 'monit')
          end
        end
      end
    end
  end
end

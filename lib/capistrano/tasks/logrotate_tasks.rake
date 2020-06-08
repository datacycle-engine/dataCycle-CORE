# frozen_string_literal: true

namespace :datacycle do
  namespace :logrotate do
    desc 'Generate and push the logrotate config file for the application'
    task :deploy_config do
      on roles(:all) do
        with rails_env: fetch(:rails_env) do
          template_name = 'logrotate'
          core_file_path = Dir.pwd + "/vendor/gems/data-cycle-core/config/deploy/templates/logrotate/#{template_name}.erb"
          file_path = Dir.pwd + "/config/deploy/templates/logrotate/#{template_name}.erb"
          if File.exist?(file_path)
            template = ERB.new(File.new(file_path).read).result(binding)
          else
            template = ERB.new(File.new(core_file_path).read).result(binding)
          end
          target_file_name = fetch(:application)
          upload! StringIO.new(template), "/tmp/#{target_file_name}"
          execute "sudo mv /tmp/#{target_file_name} /etc/logrotate.d/#{target_file_name}"
          execute "sudo chown root:root /etc/logrotate.d/#{target_file_name}"
          execute "sudo chmod o+r /etc/logrotate.d/#{target_file_name}"
        end
      end
    end

    desc 'validate the logrotate config file for the application'
    task :validate_config do
      target_file_name = "/etc/logrotate.d/#{fetch(:application)}"
      remote_config_file_exists(target_file_name, 'logrotate')
    end
  end
end

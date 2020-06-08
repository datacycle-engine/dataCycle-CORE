# frozen_string_literal: true

namespace :datacycle do
  namespace :duplicity do
    desc 'Generate and push the duplicity config file for the application'
    task :deploy_config do
      on roles(:all) do
        with rails_env: fetch(:rails_env) do
          ['backup.sh', 'filelist.txt'].each do |template_name|
            core_file_path = Dir.pwd + "/vendor/gems/data-cycle-core/config/deploy/templates/duplicity/#{template_name}.erb"
            file_path = Dir.pwd + "/config/deploy/templates/duplicity/#{template_name}.erb"
            if File.exist?(file_path)
              template = ERB.new(File.new(file_path).read).result(binding)
            else
              template = ERB.new(File.new(core_file_path).read).result(binding)
            end
            target_file_name = "#{fetch(:application)}-#{template_name}"
            upload! StringIO.new(template), "/tmp/#{target_file_name}"
            execute "mkdir -p /home/#{fetch(:deploy_user)}/scripts" if template_name == 'backup.sh'
            execute "sudo mv /tmp/#{target_file_name} /home/#{fetch(:deploy_user)}/scripts/#{target_file_name}"
            execute "sudo chmod +x /home/#{fetch(:deploy_user)}/scripts/#{target_file_name}" if template_name == 'backup.sh'
          end
        end
      end
    end

    desc 'validate the duplicity config files for the application'
    task :validate_config do
      on roles(:all) do
        with rails_env: fetch(:rails_env) do
          ['backup.sh', 'filelist.txt'].each do |template_name|
            target_file_name = "/home/#{fetch(:deploy_user)}/scripts/#{fetch(:application)}-#{template_name}"
            remote_config_file_exists(target_file_name, 'duplicity')
          end
        end
      end
    end
  end
end

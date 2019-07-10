# frozen_string_literal: true

namespace :datacycle do
  namespace :nginx do
    desc 'Generate and push the nginx config file for the application'
    task :deploy_config, [:template_name] do |_, args|
      on roles(:all) do
        with rails_env: fetch(:rails_env) do
          template_name = args[:template_name]
          core_file_path = Dir.pwd + "/vendor/gems/data-cycle-core/config/deploy/templates/nginx/#{template_name}.erb"
          file_path = Dir.pwd + "/config/deploy/templates/nginx/#{template_name}.erb"
          if File.exist?(file_path)
            template = ERB.new(File.new(file_path).read).result(binding)
          else
            template = ERB.new(File.new(core_file_path).read).result(binding)
          end
          target_file_name = fetch(:server_name)
          upload! StringIO.new(template), "/tmp/#{target_file_name}"
          execute "sudo mv /tmp/#{target_file_name} /etc/nginx/conf.d/#{target_file_name}"
        end
      end
    end

    desc 'Reload Nginx'
    task :reload do
      on roles(:all) do
        execute 'sudo service nginx reload', raise_on_non_zero_exit: false
      end
    end

    desc 'validate the nginx config file for the application'
    task :validate_config do
      target_file_name = "/etc/nginx/conf.d/#{fetch(:server_name)}"
      remote_config_file_exists(target_file_name, 'nginx')
    end
  end
end

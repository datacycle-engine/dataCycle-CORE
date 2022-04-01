# frozen_string_literal: true

namespace :datacycle do
  namespace :proxmox do
    desc 'Generate and push the duplicity config file for the application'
    task :deploy_config do
      on roles(:all) do
        within fetch(:deploy_to) do
          template_name = '.pxarexclude'
          core_file_path = Dir.pwd + "/vendor/gems/data-cycle-core/config/deploy/templates/proxmox/#{template_name}.erb"
          file_path = Dir.pwd + "/config/deploy/templates/proxmox/#{template_name}.erb"
          if File.exist?(file_path)
            template = ERB.new(File.new(file_path).read).result(binding)
          else
            template = ERB.new(File.new(core_file_path).read).result(binding)
          end
          upload! StringIO.new(template), "#{fetch(:deploy_to)}/#{template_name}"
        end
      end
    end
  end
end

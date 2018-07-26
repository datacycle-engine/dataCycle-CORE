# frozen_string_literal: true

namespace :datacycle do
  namespace :dev do
    desc 'update project: dump database - update all templates + external sources'
    task :update_project do
      on roles(:all) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            print_message 'Update Project'
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:db:dump"
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:refactor:import_update_all_templates[#{fetch(:cmd_prefix, '')}]"
            execute :rake, "#{fetch(:cmd_prefix, '')}data_cycle_core:update:import_external_source_configs"
          end
        end
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

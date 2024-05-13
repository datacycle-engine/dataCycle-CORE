# frozen_string_literal: true

require 'rufus-scheduler'
require 'yaml'

module DataCycleCore
  class RufusYamlScheduler
    def initialize
      @scheduler = Rufus::Scheduler.new
      @rails_env = ENV['RAILS_ENV'] || 'development'
      @paths = [
        Dir[File.join(Dir.pwd, 'vendor', 'gems', 'data-cycle-core', 'config', 'configurations', 'schedule.yml')],
        Dir[File.join(Dir.pwd, 'vendor', 'gems', 'data-cycle-core', 'config', 'configurations', @rails_env, 'schedule.yml')],
        Dir[File.join(Dir.pwd, 'config', 'configurations', 'schedule.yml')],
        Dir[File.join(Dir.pwd, 'config', 'configurations', @rails_env, 'schedule.yml')]
      ]
    end

    def run
      configs = []

      @paths.each do |path|
        path.each do |file_path|
          config = YAML.safe_load_file(file_path, permitted_classes: [Symbol])
          configs.concat(config) if config.is_a?(::Array)
        end
      end

      configs.each do |config|
        if config.key?('type') || config.key?('task')
          task_type = config['type'] || 'cron'

          @scheduler.send(task_type, config['time']) do
            Array(config['task']).each do |task|
              system "rake #{task}"
            end
          end
        else
          config.each do |cron_rule, tasks|
            @scheduler.cron cron_rule do
              tasks.each do |task|
                system "rake #{task}"
              end
            end
          end
        end
      end

      @scheduler.join
    end
  end
end

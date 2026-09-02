# frozen_string_literal: true

require 'rufus-scheduler'
require 'shellwords'
require 'yaml'

module DataCycleCore
  class RufusYamlScheduler
    # rufus re-triggers a rule while the previous run is still going; run_task blocks on a full `rails` boot, so overlap would stack one process per firing.
    JOB_OPTIONS = { overlap: false }.freeze

    def initialize
      @scheduler = Rufus::Scheduler.new
      @rails_env = ENV['RAILS_ENV'] || 'development'
      # core first, then every vendored datacycle gem (schemas, connectors, features), then the
      # project: a schedule that belongs to a schema or connector ships with it instead of being
      # copied into each project's schedule.yml. The globs do not match data-cycle-core above.
      @paths = [
        Dir[File.join(Dir.pwd, 'vendor', 'gems', 'data-cycle-core', 'config', 'configurations', 'schedule.yml')],
        Dir[File.join(Dir.pwd, 'vendor', 'gems', 'data-cycle-core', 'config', 'configurations', @rails_env, 'schedule.yml')],
        Dir[File.join(Dir.pwd, 'vendor', 'gems', 'datacycle-*', 'config', 'configurations', 'schedule.yml')],
        Dir[File.join(Dir.pwd, 'vendor', 'gems', 'datacycle-*', 'config', 'configurations', @rails_env, 'schedule.yml')],
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

          @scheduler.send(task_type, config['time'], JOB_OPTIONS) do
            Array(config['task']).each do |task|
              run_task(task)
            end
          end
        else
          config.each do |cron_rule, tasks|
            @scheduler.cron(cron_rule, JOB_OPTIONS) do
              tasks.each do |task|
                run_task(task)
              end
            end
          end
        end
      end

      @scheduler.join
    end

    def run_task(task)
      return if task.nil? || task.strip.empty?

      # multi-arg form: ruby execs rails directly instead of going through a shell,
      # so a task string can never inject commands. Shellwords.split reproduces the
      # argument splitting/quote removal the shell did before, e.g.
      # dc:import:append_job['canto_dam'] -> dc:import:append_job[canto_dam]
      system('rails', *Shellwords.split(task))
    end
  end
end

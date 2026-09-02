# frozen_string_literal: true

require 'rake'

module DataCycleCore
  # Runs rake tasks from inside the app — jobs and import steps, where rake is not the entry point.
  class RakeTaskService
    LOAD_MUTEX = Mutex.new

    class << self
      # @param name [String] full task name, e.g. 'dc:classifications:merge:create_distinct_tree'
      # @param args [Array, String, nil] positional arguments for the task
      def invoke(name, args = nil)
        load_tasks

        task = Rake::Task[name]
        # a task stays invoked for the life of the process, and re-raises its first exception
        task.reenable
        task.invoke(*Array.wrap(args))
      end

      # Job workers boot through config/environment (bin/jobs), where no rake task is defined yet.
      # Loading twice appends every task body a second time, so `environment` marks a filled registry.
      def load_tasks
        LOAD_MUTEX.synchronize do
          Rails.application.load_tasks unless Rake::Task.task_defined?('environment')
        end
      end
    end
  end
end

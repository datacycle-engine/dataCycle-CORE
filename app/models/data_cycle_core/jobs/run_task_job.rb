# frozen_string_literal: true

require 'rake'

module DataCycleCore
  module Jobs
    RunTaskJob = Struct.new(:task, :args) do
      def perform
        Rake::Task.clear
        Rails.application.load_tasks
        self.args ||= []
        Rake::Task[task].invoke(*Array.wrap(self.args))
      end

      def enqueue(job)
        job.priority = 0
        job.delayed_reference_id = task
        job.delayed_reference_type = task
      end
    end
  end
end
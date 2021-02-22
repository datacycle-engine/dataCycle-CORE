# frozen_string_literal: true

module DataCycleCore
  class RunTaskJob < ApplicationJob
    queue_as :default

    def perform(task, args = [])
      Rake::Task.clear
      Rails.application.load_tasks
      Rake::Task[task].invoke(*Array.wrap(args))
    end

    around_enqueue do |_job, block|
      block.call unless Delayed::Job.exists?(queue: queue_name, delayed_reference_type: delayed_reference_type, delayed_reference_id: delayed_reference_id(*arguments), locked_at: nil)
    end

    def priority
      0
    end

    after_enqueue do |job|
      Delayed::Job.find_by(id: job.provider_job_id)&.update_columns(delayed_reference_id: delayed_reference_id(*arguments), delayed_reference_type: delayed_reference_type)
    end

    def delayed_reference_id(task, *_args)
      task.to_s
    end

    def delayed_reference_type
      'rake_task'
    end
  end
end

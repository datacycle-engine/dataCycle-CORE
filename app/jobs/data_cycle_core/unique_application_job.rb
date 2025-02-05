# frozen_string_literal: true

module DataCycleCore
  class UniqueApplicationJob < ApplicationJob
    def delayed_reference_id
      raise 'NOT IMPLEMENTED'
    end

    def delayed_reference_type
      raise 'NOT IMPLEMENTED'
    end

    before_enqueue ->(job) { job.clear_previous_jobs }

    # clear all previous jobs for the same reference
    def clear_previous_jobs
      previous_jobs = Delayed::Job.where(
        queue: queue_name,
        delayed_reference_id:,
        delayed_reference_type:,
        locked_at: nil,
        failed_at: nil
      )
        .order(run_at: :asc)

      first_job = previous_jobs.first

      return unless first_job

      self.scheduled_at = first_job.run_at if first_job.run_at < Time.zone.now
      previous_jobs.delete_all
    end
  end
end

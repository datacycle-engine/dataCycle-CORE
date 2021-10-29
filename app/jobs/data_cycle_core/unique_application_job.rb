# frozen_string_literal: true

module DataCycleCore
  class UniqueApplicationJob < ApplicationJob
    def delayed_reference_id
      raise 'NOT IMPLEMENTED'
    end

    def delayed_reference_type
      raise 'NOT IMPLEMENTED'
    end

    around_enqueue do |job, block|
      block.call unless Delayed::Job.exists?(
        queue: job.queue_name,
        delayed_reference_type: job.delayed_reference_type,
        delayed_reference_id: job.delayed_reference_id,
        locked_at: nil,
        failed_at: nil
      )
    end

    after_enqueue do |job|
      Delayed::Job.find_by(id: job.provider_job_id)&.update_columns(
        delayed_reference_type: job.delayed_reference_type,
        delayed_reference_id: job.delayed_reference_id
      )
    end
  end
end

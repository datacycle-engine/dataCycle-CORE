# frozen_string_literal: true

module DataCycleCore
  class BroadcastDashboardUpdateJob < ApplicationJob
    queue_as :cache_invalidation
    PRIORITY = 0
    REFERENCE_ID = 'admin_dash_board'

    before_enqueue :check_existing_jobs

    def delayed_reference_id
      REFERENCE_ID
    end

    def delayed_reference_type
      self.class.name.demodulize
    end

    def priority
      PRIORITY
    end

    def discard_on_failure?
      true
    end

    def perform # rubocop:disable Naming/PredicateMethod
      # This job is used to trigger a broadcast for dashboard updates.
      # It does not perform any specific action other than broadcasting.
      # The actual logic is handled in the after_perform callback.
      # This is a placeholder to ensure the job runs.
      true
    end

    # broadcast update on destroy
    def self.broadcast_dashboard_jobs_now?
      true
    end

    private

    def check_existing_jobs
      throw :abort if Delayed::Job.exists?(
        queue: queue_name,
        delayed_reference_type:,
        failed_at: nil
      )

      self.scheduled_at ||= 5.seconds.from_now.to_f
    end
  end
end

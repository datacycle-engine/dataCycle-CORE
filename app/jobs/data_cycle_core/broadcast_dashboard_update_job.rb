# frozen_string_literal: true

module DataCycleCore
  class BroadcastDashboardUpdateJob < ApplicationJob
    queue_as :cache_invalidation
    queue_with_reference_id -> { 'admin_dash_board' }
    queue_with_reference_type -> { self.class.name.demodulize }

    before_enqueue :check_existing_jobs
    after_perform :broadcast_self

    def discard_on_failure?
      true
    end

    def perform
      DataCycleCore::StatsJobQueue.broadcast_jobs_reload
    end

    private

    def check_existing_jobs
      throw :abort if Delayed::Job.exists?(
        queue: queue_name,
        delayed_reference_type:,
        locked_at: nil,
        failed_at: nil
      )

      self.scheduled_at ||= 1.minute.from_now.to_f
    end

    def broadcast_self
      DataCycleCore::StatsJobQueue.broadcast_jobs_reload
    end
  end
end

# frozen_string_literal: true

module DelayedJobActiveRecordExtension
  extend ActiveSupport::Concern

  included do
    after_destroy_commit :broadcast_dashboard_jobs_reload
  end

  private

  def broadcast_dashboard_jobs_reload
    if payload_object&.job_data&.dig('job_class')&.safe_constantize.try(:broadcast_dashboard_jobs_now?)
      DataCycleCore::StatsJobQueue.broadcast_jobs_reload
    else
      DataCycleCore::StatsJobQueue.broadcast_throttled_jobs_reload
    end
  end
end

Delayed::Backend::ActiveRecord::Job.include(DelayedJobActiveRecordExtension)

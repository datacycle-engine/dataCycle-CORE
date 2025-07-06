# frozen_string_literal: true

module DelayedJobActiveRecordExtension
  extend ActiveSupport::Concern

  included do
    after_destroy_commit :broadcast_dashboard_jobs_reload
  end

  private

  def broadcast_dashboard_jobs_reload
    return unless payload_object.job_data['job_class'].safe_constantize.try(:broadcast_dashboard_jobs_reload?)

    DataCycleCore::TurboService.broadcast_update_to(
      'admin_dashboard_jobs',
      partial: 'data_cycle_core/dash_board/job_queue_body'
    )
  end
end

Delayed::Backend::ActiveRecord::Job.include(DelayedJobActiveRecordExtension)

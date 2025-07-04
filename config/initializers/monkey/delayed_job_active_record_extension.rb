# frozen_string_literal: true

module DelayedJobActiveRecordExtension
  extend ActiveSupport::Concern

  included do
    after_destroy :broadcast_reload
  end

  private

  def broadcast_reload
    html = DataCycleCore::PartialRenderService.instance.render(partial: 'data_cycle_core/dash_board/job_queue_body')
    Turbo::StreamsChannel.broadcast_update_to 'admin_dashboard_jobs', html:, target: 'admin_dashboard_jobs'
  end
end

Delayed::Backend::ActiveRecord::Job.include(DelayedJobActiveRecordExtension)

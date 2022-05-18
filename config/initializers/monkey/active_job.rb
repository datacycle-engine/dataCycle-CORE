# frozen_string_literal: true

module ActiveJobMetricsExtension
  def success(job)
    # rubocop:disable Security/YAMLLoad, Style/GuardClause
    ActiveSupport::Notifications.instrument 'job_succeeded.datacycle', this: {
      job_queue: job.queue,
      job_class: YAML.load(job.handler).class.name,
      waiting_time: job.created_at ? (Time.zone.now - job.created_at) / 60 : nil,
      attempt_count: job.attempts
    }
    # rubocop:enable Security/YAMLLoad, Style/GuardClause
  end
end

ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.prepend(ActiveJobMetricsExtension)

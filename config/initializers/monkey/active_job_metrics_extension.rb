# frozen_string_literal: true

module ActiveJobMetricsExtension
  def success(job)
    # rubocop:disable Security/YAMLLoad
    ActiveSupport::Notifications.instrument 'job_succeeded.datacycle', {
      job_queue: job.queue,
      job_class: YAML.load(job.handler, permitted_classes: [Symbol, ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper]).class.name,
      waiting_time: job.created_at ? (Time.zone.now - job.created_at) / 60 : nil,
      attempt_count: job.attempts
    }
    # rubocop:enable Security/YAMLLoad
  end

  def max_attempts
    job_class = job_data['job_class']&.safe_constantize
    max_attempts = job_class::ATTEMPTS if job_class&.const_defined?(:ATTEMPTS)
    max_attempts || 5
  end
end

ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.prepend(ActiveJobMetricsExtension)

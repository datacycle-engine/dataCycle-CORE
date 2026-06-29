# frozen_string_literal: true

module ActiveJobMetricsExtension
  def max_attempts
    job_class = job_data['job_class']&.safe_constantize
    max_attempts = job_class::ATTEMPTS if job_class&.const_defined?(:ATTEMPTS)
    max_attempts || 5
  end
end

ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.prepend(ActiveJobMetricsExtension)

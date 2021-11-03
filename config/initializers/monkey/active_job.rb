# frozen_string_literal: true

module ActiveJobMetricsExtension
  def success(job)
    # rubocop:disable Security/YAMLLoad
    Appsignal.add_distribution_value('delayed_job.waiting_time', (Time.zone.now - job.created_at) / 60,
                                     { job_class: YAML.load(job.handler).job_data['job_class'], queue: job.queue })
    Appsignal.add_distribution_value('delayed_job.attempt_count', job.attempts,
                                     { job_class: YAML.load(job.handler).job_data['job_class'], queue: job.queue })
    # rubocop:enable LSecurity/YAMLLoad
  end
end

ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.prepend(ActiveJobMetricsExtension)

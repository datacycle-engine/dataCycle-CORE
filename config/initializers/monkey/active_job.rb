# frozen_string_literal: true

module ActiveJobMetricsExtension
  def success(job)
    # rubocop:disable Security/YAMLLoad, Style/GuardClause
<<<<<<< HEAD
    ActiveSupport::Notifications.instrument 'job_succeeded.datacycle', this: {
      job_queue: job.queue,
      job_class: YAML.load(job.handler).class.name,
      waiting_time: job.created_at ? (Time.zone.now - job.created_at) / 60 : nil,
      attempt_count: job.attempts
    }
=======
    if job.created_at
      Appsignal.add_distribution_value('delayed_job.waiting_time', (Time.zone.now - job.created_at) / 60,
                                       { job_class: YAML.load(job.handler).job_data['job_class'], queue: job.queue })
    end

    if job.attempts
      Appsignal.add_distribution_value('delayed_job.attempt_count', job.attempts,
                                       { job_class: YAML.load(job.handler).job_data['job_class'], queue: job.queue })
    end
>>>>>>> old/develop
    # rubocop:enable Security/YAMLLoad, Style/GuardClause
  end
end

ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.prepend(ActiveJobMetricsExtension)

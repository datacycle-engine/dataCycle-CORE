# frozen_string_literal: true

module ActiveJobMetricsExtension
  def success(job)
    # rubocop:disable Security/YAMLLoad, Style/GuardClause
    if job.created_at
      Appsignal.add_distribution_value('delayed_job.waiting_time', (Time.zone.now - job.created_at) / 60,
                                       { job_class: YAML.load(job.handler).job_data['job_class'], queue: job.queue })
    end

    if job.attempts
      Appsignal.add_distribution_value('delayed_job.attempt_count', job.attempts,
                                       { job_class: YAML.load(job.handler).job_data['job_class'], queue: job.queue })
    end
    # rubocop:enable Security/YAMLLoad, Style/GuardClause
  end
end

module ActiveJobDelayedJobAdapterExtension
  def enqueue(job) # :nodoc:
    delayed_job = Delayed::Job.enqueue(
      ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.new(job.serialize),
      queue: job.queue_name,
      priority: job.priority,
      delayed_reference_id: job.try(:delayed_reference_id),
      delayed_reference_type: job.try(:delayed_reference_type)
    )
    job.provider_job_id = delayed_job.id
    delayed_job
  end

  def enqueue_at(job, timestamp) # :nodoc:
    delayed_job = Delayed::Job.enqueue(
      ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.new(job.serialize),
      queue: job.queue_name,
      priority: job.priority,
      run_at: Time.zone.at(timestamp),
      delayed_reference_id: job.try(:delayed_reference_id),
      delayed_reference_type: job.try(:delayed_reference_type)
    )
    job.provider_job_id = delayed_job.id
    delayed_job
  end
end

ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.prepend(ActiveJobMetricsExtension)
ActiveJob::QueueAdapters::DelayedJobAdapter.prepend(ActiveJobDelayedJobAdapterExtension)

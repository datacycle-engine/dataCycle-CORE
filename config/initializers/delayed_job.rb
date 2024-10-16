# frozen_string_literal: true

Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_run_time = 7.days
Delayed::Worker.max_attempts = 1 # retries are handled by ActiveJob
Delayed::Worker.sleep_delay = Rails.env.development? ? 5 : 60
# to execute all jobs immediately without queue: false
Delayed::Worker.delay_jobs = ->(job) { !Rails.env.test? && job.queue != 'inline' }
Delayed::Worker.default_queue_name = 'default'
Delayed::Worker.default_priority = 5
Delayed::Worker.raise_signal_exceptions = true # :term tries to finish running jobs, but doesnt resume them after restart if they didnt finish in time (they would be resumed after Delayed::Worker.max_run_time)
Delayed::Worker.logger = Logger.new(Rails.root.join('log', 'delayed_job.log'))

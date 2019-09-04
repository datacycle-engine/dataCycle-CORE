# frozen_string_literal: true

Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_run_time = 7.days
Delayed::Worker.max_attempts = 10
Delayed::Worker.sleep_delay = 60
# to execute all jobs immediately without queue: false
Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.default_queue_name = 'default'
Delayed::Worker.default_priority = 5
Delayed::Worker.raise_signal_exceptions = :term
Delayed::Worker.logger = Logger.new(Rails.root.join('log', 'delayed_job.log'))

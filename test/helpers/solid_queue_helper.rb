# frozen_string_literal: true

module DataCycleCore
  # Writes the solid_queue_jobs rows that the enqueue guards in DataCycleCore::UniqueApplicationJob
  # read. The test env runs the :test queue adapter, so no test ever puts a job on the real queue:
  # the state a guard is meant to recognise — one job holding the concurrency semaphore, a second
  # waiting behind it — has to be created here, or the guard finds nothing and every assertion about
  # it passes for the wrong reason.
  module SolidQueueHelper
    # SolidQueue readies the first row for a concurrency key and blocks every one after it, so two
    # calls with the same job build a full :block conflict.
    # @param job [ActiveJob::Base] the job whose queue name, class and concurrency key the row carries
    # @param key [String] concurrency key override, e.g. to write a row for an unrelated key
    # @param arguments [Hash] serialized payload override, e.g. to write a row with other arguments
    # @return [SolidQueue::Job] the created row
    def create_queue_row(job, key: job.concurrency_key, arguments: job.serialize)
      SolidQueue::Job.create!(queue_name: job.queue_name, class_name: job.class.name, arguments:, concurrency_key: key)
    end
  end
end

ActiveSupport.on_load(:active_support_test_case) { include DataCycleCore::SolidQueueHelper }

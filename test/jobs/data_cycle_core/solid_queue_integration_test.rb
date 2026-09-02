# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Drives jobs through the real Solid Queue backend — enqueue, dispatch, claim, perform, release —
  # instead of the :test adapter the rest of the suite runs on. Everywhere else the queue rows are
  # built by hand, which can only confirm that the code agrees with how those rows were imagined.
  # This is the check the MR description asked for manually ("unterschiedliche Importer dürfen
  # gleichzeitig laufen, derselbe wird blockiert") as a permanent one.
  class SolidQueueIntegrationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # Unique by its only argument, and records what actually ran.
    class BlockingJob < DataCycleCore::UniqueApplicationJob
      cattr_accessor :performed, default: []
      # own queue per test, so claiming can address exactly the jobs that test enqueued
      cattr_accessor :test_queue, default: 'solid_queue_integration'

      queue_as { test_queue }
      limits_concurrency key: ->(key) { key }, duration: 5.minutes

      def perform(key)
        performed << key
      end
    end

    # The same job, but a duplicate is dropped at dispatch instead of queued behind the original.
    class DiscardingJob < BlockingJob
      limits_concurrency key: ->(key) { key }, duration: 5.minutes, on_conflict: :discard
    end

    JOB_CLASSES = [BlockingJob, DiscardingJob].freeze

    setup do
      BlockingJob.performed = []
      BlockingJob.test_queue = "solid-queue-test-#{SecureRandom.hex(6)}"

      @adapters = JOB_CLASSES.index_with(&:queue_adapter)
      JOB_CLASSES.each { |klass| klass.enable_test_adapter(ActiveJob::QueueAdapters::SolidQueueAdapter.new) }

      @process = SolidQueue::Process.register(kind: 'Worker', name: "worker-#{SecureRandom.hex(6)}", pid: rand(10_000..99_999), hostname: 'test-host')
    end

    teardown do
      @adapters.each { |klass, adapter| klass.enable_test_adapter(adapter) }
    end

    # Claims everything ready on this test's queue and runs it, the way a worker's thread would.
    # @return [Integer] number of jobs performed
    def work_off
      SolidQueue::ReadyExecution.claim([BlockingJob.test_queue], 10, @process.id)

      SolidQueue::ClaimedExecution.where(process_id: @process.id).to_a.each(&:perform).size
    end

    def queue_row(job)
      SolidQueue::Job.find_by!(active_job_id: job.job_id)
    end

    def enqueued_count
      SolidQueue::Job.where(queue_name: BlockingJob.test_queue).count
    end

    test 'a second job for the same key waits behind the first instead of running with it' do
      first = BlockingJob.perform_later('a')
      second = BlockingJob.perform_later('a')

      assert_predicate queue_row(first), :ready?
      assert_predicate queue_row(second), :blocked?
      assert_equal 1, work_off
      assert_equal ['a'], BlockingJob.performed
    end

    test 'jobs for different keys are both ready and run alongside each other' do
      first = BlockingJob.perform_later('a')
      second = BlockingJob.perform_later('b')

      assert_predicate queue_row(first), :ready?
      assert_predicate queue_row(second), :ready?
      assert_equal 2, work_off
      assert_equal ['a', 'b'], BlockingJob.performed.sort
    end

    test 'a third job for the same key is not enqueued at all' do
      BlockingJob.perform_later('a')
      BlockingJob.perform_later('a')

      assert_not BlockingJob.perform_later('a')
      assert_equal 2, enqueued_count
    end

    test 'finishing a job releases the duplicate blocked behind it' do
      BlockingJob.perform_later('a')
      blocked = BlockingJob.perform_later('a')

      assert_equal 1, work_off
      assert_predicate queue_row(blocked), :ready?

      assert_equal 1, work_off
      assert_equal ['a', 'a'], BlockingJob.performed
    end

    test 'on_conflict :discard drops the duplicate rather than queueing it' do
      DiscardingJob.perform_later('a')

      assert_not DiscardingJob.perform_later('a')
      assert_equal 1, enqueued_count
    end

    test 'the semaphore is released again once the queue for a key has run dry' do
      job = BlockingJob.perform_later('a')
      key = queue_row(job).concurrency_key

      assert SolidQueue::Semaphore.exists?(key:, value: 0)
      assert_equal 1, work_off
      assert_not SolidQueue::Semaphore.exists?(key:, value: 0)
    end
  end
end

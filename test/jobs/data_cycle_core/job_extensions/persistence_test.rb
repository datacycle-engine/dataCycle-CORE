# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module JobExtensions
    class PersistenceTest < DataCycleCore::TestCases::ActiveSupportTestCase
      setup do
        # ImportJob limits concurrency by its first argument (external_system id) with a 15 minute duration
        @uuid = SecureRandom.uuid
        @job = DataCycleCore::ImportJob.new(@uuid)
        @key = @job.concurrency_key
      end

      # Enqueues a job that ends up blocked on the concurrency semaphore. A held semaphore
      # (value 0) forces SolidQueue to create a BlockedExecution instead of a ReadyExecution
      # via the job's +prepare_for_execution+ callback.
      def create_blocked_job(expires_at:, key: @key, arguments: @job.serialize)
        SolidQueue::Semaphore.create!(key:, value: 0, expires_at: 1.hour.from_now) unless SolidQueue::Semaphore.exists?(key:)

        sq_job = SolidQueue::Job.create!(
          queue_name: 'importers',
          class_name: @job.class.name,
          arguments:,
          concurrency_key: key
        )

        SolidQueue::BlockedExecution.find_by!(job_id: sq_job.id).tap { |blocked| blocked.update!(expires_at:) }
      end

      # Enqueues a job that successfully acquires the semaphore and therefore becomes *ready*
      # instead of blocked. This is the first job for a concurrency key, i.e. exactly the duplicate
      # a blocked-execution-only lookup cannot see.
      def create_ready_job(key: @key, arguments: @job.serialize)
        SolidQueue::Job.create!(
          queue_name: 'importers',
          class_name: @job.class.name,
          arguments:,
          concurrency_key: key
        )
      end

      test 'extend_concurrency_lock refreshes the held semaphore even without a blocked duplicate' do
        # the running job holds the semaphore and has no blocked execution
        semaphore = SolidQueue::Semaphore.create!(key: @key, value: 0, expires_at: 1.hour.ago)

        assert_no_difference -> { SolidQueue::BlockedExecution.count } do
          @job.extend_concurrency_lock
        end

        # the held semaphore must be pushed forward by (about) the concurrency duration
        assert_operator semaphore.reload.expires_at, :>, 10.minutes.from_now
      end

      test 'extend_concurrency_lock also extends a blocked duplicate and its semaphore' do
        semaphore = SolidQueue::Semaphore.create!(key: @key, value: 0, expires_at: 1.hour.ago)
        blocked = create_blocked_job(expires_at: 1.hour.ago)

        @job.extend_concurrency_lock

        assert_operator blocked.reload.expires_at, :>, 10.minutes.from_now
        assert_operator semaphore.reload.expires_at, :>, 10.minutes.from_now
      end

      test 'duplicate_queued_with_args? matches a blocked job with identical arguments' do
        create_blocked_job(expires_at: 1.hour.from_now)

        assert_predicate @job, :duplicate_queued_with_args?
      end

      test 'duplicate_queued_with_args? ignores blocked jobs with different arguments' do
        create_blocked_job(expires_at: 1.hour.from_now)

        # same concurrency key (first arg), but different arguments
        other = DataCycleCore::ImportJob.new(@uuid, 'full')

        assert_equal @key, other.concurrency_key
        assert_not other.duplicate_queued_with_args?
      end

      test 'duplicate_queued_with_args? matches a ready duplicate that holds the semaphore' do
        ready = create_ready_job

        # nothing is blocked here, so a blocked-execution-only lookup would report no duplicate
        assert_predicate ready, :ready?
        assert_empty SolidQueue::BlockedExecution.where(concurrency_key: @key)
        assert_predicate @job, :duplicate_queued_with_args?
      end

      test 'duplicate_queued_with_args? still matches a blocked duplicate whose lock expired' do
        # an expired lock only means concurrency maintenance has not released the job yet;
        # it is still queued and will run, so it is a genuine duplicate
        create_blocked_job(expires_at: 1.hour.ago)

        assert_predicate @job, :duplicate_queued_with_args?
      end

      test 'duplicate_queued_with_args? ignores finished jobs' do
        create_ready_job.update!(finished_at: Time.current)

        assert_not @job.duplicate_queued_with_args?
      end

      test 'duplicate_queued_with_args? ignores jobs with a different concurrency key' do
        create_ready_job(key: "importers/#{SecureRandom.uuid}")

        assert_not @job.duplicate_queued_with_args?
      end

      test 'duplicate_queued_with_args? ignores the job asking about itself' do
        sq_job = create_ready_job
        @job.provider_job_id = sq_job.id

        assert_not @job.duplicate_queued_with_args?
      end

      # a permanently failed job is the only row that outlives its run (preserve_finished_jobs is
      # off), and it must not keep its external system unimportable for good
      test 'duplicate_queued_with_args? ignores a permanently failed job' do
        create_ready_job.failed_with(StandardError.new('boom'))

        assert_not @job.duplicate_queued_with_args?
      end

      # duplicate_queued_with_args? compares against the arguments ActiveJob itself wrote into the
      # row, and builds its operand with ActiveJob's private +serialize_arguments_if_needed+. Neither
      # a renamed method nor a changed serialization would raise in production — the query would
      # simply stop matching and duplicates would queue up again — so pin both sides here.
      test 'the argument comparison is built exactly as ActiveJob stores the arguments' do
        row = create_ready_job
        job = DataCycleCore::WatchListSubscriberNotificationJob.new(row, 'plain', { 'a' => 1 })
        serialized = job.send(:serialize_arguments_if_needed, job.arguments)

        # a record argument becomes a GlobalId: this is what tells two argument lists apart in the
        # query, and it is what the row holds
        assert_equal row.to_global_id.to_s, serialized.first['_aj_globalid']
        assert_equal job.serialize['arguments'], serialized
      end

      test 'duplicate_queued? only sees a blocked duplicate, not the ready one holding the lock' do
        ready = create_ready_job

        assert_predicate ready, :ready?
        assert_not @job.duplicate_queued?

        create_blocked_job(expires_at: 1.hour.from_now)

        assert_predicate @job, :duplicate_queued?
      end

      test 'duplicate_pending? sees the ready job holding the lock, which duplicate_queued? misses' do
        create_ready_job

        assert_predicate @job, :duplicate_pending?
      end

      test 'duplicate_pending? ignores arguments, unlike duplicate_queued_with_args?' do
        create_ready_job

        other = DataCycleCore::ImportJob.new(@uuid, 'full')

        assert_equal @key, other.concurrency_key
        assert_not other.duplicate_queued_with_args?
        assert_predicate other, :duplicate_pending?
      end

      test 'duplicate_pending? ignores finished and permanently failed jobs' do
        create_ready_job.update!(finished_at: Time.current)
        create_ready_job.failed_with(StandardError.new('boom'))

        assert_not @job.duplicate_pending?
      end

      test 'duplicate_pending? ignores the job asking about itself' do
        @job.provider_job_id = create_ready_job.id

        assert_not @job.duplicate_pending?
      end

      test 'duplicate_pending? is false for jobs without a concurrency key' do
        assert_not keyless_job.duplicate_pending?
      end

      test 'extend_concurrency_lock only touches the matching concurrency key' do
        other_key = "importers/#{SecureRandom.uuid}"
        other = SolidQueue::Semaphore.create!(key: other_key, value: 0, expires_at: 1.hour.ago)
        SolidQueue::Semaphore.create!(key: @key, value: 0, expires_at: 1.hour.ago)

        @job.extend_concurrency_lock

        assert_operator other.reload.expires_at, :<, Time.current
      end

      # WatchListSubscriberNotificationJob declares no limits_concurrency, so it has no key to lock
      def keyless_job
        DataCycleCore::WatchListSubscriberNotificationJob.new
      end

      test 'extend_concurrency_lock is a no-op for jobs without a concurrency key' do
        job = keyless_job

        assert_nil job.concurrency_key
        assert_nothing_raised { job.extend_concurrency_lock }
      end

      test 'with_extended_concurrency_lock refreshes the lock while the block runs' do
        refreshes = Concurrent::AtomicFixnum.new(0)

        # the refresh runs on its own thread, which in a transactional test cannot see this
        # transaction's rows — so count the calls instead of asserting on the semaphore
        @job.stub(:concurrency_duration, 0.3.seconds) do
          @job.stub(:extend_concurrency_lock, ->(*) { refreshes.increment }) do
            @job.with_extended_concurrency_lock { sleep 0.6 }
          end
        end

        assert_operator refreshes.value, :>=, 1
      end

      test 'with_extended_concurrency_lock returns the block result' do
        assert_equal(:done, @job.with_extended_concurrency_lock { :done })
      end

      test 'with_extended_concurrency_lock lets errors through' do
        assert_raises(RuntimeError) { @job.with_extended_concurrency_lock { raise 'boom' } }
      end

      test 'with_extended_concurrency_lock just yields for jobs without a concurrency key' do
        job = keyless_job

        assert_nil job.concurrency_key
        assert_equal(:done, job.with_extended_concurrency_lock { :done })
      end
    end
  end
end

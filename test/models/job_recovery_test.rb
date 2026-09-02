# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class JobRecoveryTest < DataCycleCore::TestCases::ActiveSupportTestCase
    setup do
      @dead = register_process(heartbeat: (SolidQueue.process_alive_threshold + 1.minute).ago)
      @live = register_process
    end

    def register_process(heartbeat: nil)
      SolidQueue::Process.register(kind: 'Worker', name: "worker-#{SecureRandom.hex(6)}", pid: rand(10_000..99_999), hostname: 'test-host')
        .tap { |process| process.update_column(:last_heartbeat_at, heartbeat) if heartbeat }
    end

    # A job that acquired its concurrency lock on enqueue and is waiting to be picked up. Each job
    # gets its own queue so that +claim+ can address it unambiguously.
    def create_ready_job(key: "importers/#{SecureRandom.uuid}")
      job = DataCycleCore::ImportJob.new(SecureRandom.uuid)

      SolidQueue::Job.create!(queue_name: "queue-#{SecureRandom.hex(6)}", class_name: job.class.name, arguments: job.serialize, concurrency_key: key)
    end

    def claim(job, process)
      SolidQueue::ReadyExecution.claim([job.queue_name], 1, process.id)
      job
    end

    # Fails a job the way an outside kill does: the execution row is moved without SolidQueue
    # releasing the concurrency lock, because nothing inside +perform+ ever raised.
    def kill(job, exception_class)
      SolidQueue::FailedExecution.create!(job_id: job.id, error: { exception_class:, message: 'killed', backtrace: [] })
      SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
      SolidQueue::ClaimedExecution.where(job_id: job.id).delete_all
      job
    end

    test 'releases the claims of a process that stopped heartbeating' do
      job = claim(create_ready_job, @dead)

      assert_predicate job, :claimed?

      DataCycleCore::JobRecovery.unlock

      assert_predicate job.reload, :ready?
      assert_not SolidQueue::Process.exists?(@dead.id)
    end

    test 'leaves a running worker and its claim untouched' do
      job = claim(create_ready_job, @live)

      DataCycleCore::JobRecovery.unlock

      assert_predicate job.reload, :claimed?
      assert SolidQueue::Process.exists?(@live.id)
    end

    test 'clears a taken lock that no live job holds' do
      SolidQueue::Semaphore.create!(key: 'importers/orphaned', value: 0, expires_at: 15.minutes.from_now)

      DataCycleCore::JobRecovery.unlock

      assert_not SolidQueue::Semaphore.exists?(key: 'importers/orphaned')
    end

    test 'keeps the lock of a job that is still queued' do
      key = "importers/#{SecureRandom.uuid}"
      create_ready_job(key:)

      DataCycleCore::JobRecovery.unlock

      assert SolidQueue::Semaphore.exists?(key:)
    end

    test 'keeps the lock of a job a running worker is executing' do
      key = "importers/#{SecureRandom.uuid}"
      claim(create_ready_job(key:), @live)

      DataCycleCore::JobRecovery.unlock

      assert SolidQueue::Semaphore.exists?(key:)
    end

    test 'leaves available locks alone' do
      SolidQueue::Semaphore.create!(key: 'importers/available', value: 1, expires_at: 15.minutes.from_now)

      DataCycleCore::JobRecovery.unlock

      assert SolidQueue::Semaphore.exists?(key: 'importers/available')
    end

    test 'requeues jobs that were killed from the outside' do
      DataCycleCore::JobRecovery::INTERRUPTED_BY.each do |exception_class|
        job = kill(create_ready_job, exception_class)

        DataCycleCore::JobRecovery.unlock

        assert_predicate job.reload, :ready?, "expected #{exception_class} to be requeued"
        assert_not SolidQueue::FailedExecution.exists?(job_id: job.id)
      end
    end

    test 'a requeued job gets its lock back instead of blocking on the stale one' do
      key = "importers/#{SecureRandom.uuid}"
      job = kill(create_ready_job(key:), 'SolidQueue::Processes::ProcessPrunedError')

      # the killed job left its lock behind, which would block its own requeue
      assert SolidQueue::Semaphore.exists?(key:, value: 0)

      DataCycleCore::JobRecovery.unlock

      assert_predicate job.reload, :ready?
      assert_not_predicate job, :blocked?
      assert SolidQueue::Semaphore.exists?(key:, value: 0)
    end

    test 'keeps jobs that failed inside perform failed' do
      job = kill(create_ready_job, 'DataCycleCore::Generic::Common::Error::ImportError')

      DataCycleCore::JobRecovery.unlock

      assert_predicate job.reload, :failed?
    end

    test 'releases claims whose process row disappeared without callbacks' do
      job = claim(create_ready_job, @live)
      SolidQueue::Process.where(id: @live.id).delete_all

      assert_predicate job, :claimed?

      DataCycleCore::JobRecovery.unlock

      assert_predicate job.reload, :ready?
    end

    test 'reports what it did per step' do
      claim(create_ready_job, @dead)
      SolidQueue::Semaphore.create!(key: 'importers/orphaned', value: 0, expires_at: 15.minutes.from_now)
      kill(create_ready_job, 'SolidQueue::Processes::ProcessMissingError')

      result = DataCycleCore::JobRecovery.unlock

      assert_equal 1, result[:released_from_dead_processes]
      assert_equal 1, result[:requeued]
      assert_operator result[:cleared_locks], :>=, 1
    end

    test 'is idempotent' do
      claim(create_ready_job, @dead)
      kill(create_ready_job, 'SolidQueue::Processes::ProcessPrunedError')

      DataCycleCore::JobRecovery.unlock

      assert_equal({ released_from_dead_processes: 0, released_orphaned_claims: 0, cleared_locks: 0, requeued: 0 }, DataCycleCore::JobRecovery.unlock)
    end

    test 'finds the job tables of a migrated database' do
      assert_predicate DataCycleCore::JobRecovery, :tables_exist?
    end

    test 'reports no job tables when there is nothing to connect to' do
      SolidQueue::Job.stub(:table_exists?, ->(*) { raise ActiveRecord::NoDatabaseError }) do
        assert_not_predicate DataCycleCore::JobRecovery, :tables_exist?
      end
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WorkerMemoryGuardTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # What the stubbed SolidQueue::Worker#stop records, so a job can read mid-perform whether the
    # guard has stopped the worker out from under it.
    cattr_accessor :worker_stopped
    # Stands in for the SolidQueue::Process record the supervisor registers a worker against, whose
    # pid is what +DataCycleCore::WorkerMemoryGuard.forked?+ reads.
    SupervisorProcess = Struct.new(:pid)
    # Nothing this job does matters: the guard hangs off perform.active_job, which every job fires.
    class NoopJob < DataCycleCore::ApplicationJob
      def perform
      end
    end

    # The shape of RunTaskJob -> RakeTaskService -> ImportHelper.perform_job with run_now=true, and
    # of an ImportJob whose export fires its webhooks synchronously: perform_now from inside the job
    # the worker claimed. Records what the guard had done by the time the inline job returned.
    class InliningJob < DataCycleCore::ApplicationJob
      cattr_accessor :stopped_mid_perform

      def perform
        NoopJob.perform_now
        self.class.stopped_mid_perform = WorkerMemoryGuardTest.worker_stopped
      end
    end

    setup do
      @worker_max_memory = DataCycleCore.worker_max_memory
      DataCycleCore.worker_max_memory = 1024
    end

    teardown do
      DataCycleCore.worker_max_memory = @worker_max_memory
      DataCycleCore::WorkerMemoryGuard.instance_variable_set(:@worker, nil)
    end

    # Nothing here starts a supervisor, so the record the guard reads the forking mode off has to be
    # stood in for: this process' parent is what a forked worker's supervisor is, its own pid the
    # async supervisor's shape, and nil an unsupervised worker.
    def build_worker(threads: 1, supervisor_pid: ::Process.ppid)
      SolidQueue::Worker.new(queues: 'default', threads:, polling_interval: 1)
        .tap { |worker| worker.supervised_by(SupervisorProcess.new(supervisor_pid)) unless supervisor_pid.nil? }
    end

    # Reproduces what the guard sees while a job finishes: the slot of the job that is still in
    # +perform+ has not been restored yet, and every other running job holds one of its own.
    def with_reserved_slots(worker, count)
      count.times { worker.pool.send(:reserve_capacity!) }
      yield
    ensure
      count.times { worker.pool.send(:restore_capacity) }
    end

    # Removes only what the block subscribed, so the LogSubscriber the rest of the suite runs on
    # survives — +supervise+ retires the subscriber of an earlier call, but not its own.
    def supervising(worker)
      before = ActiveSupport::Notifications.notifier.listeners_for('perform.active_job')
      DataCycleCore::WorkerMemoryGuard.supervise(worker)
      yield
    ensure
      (ActiveSupport::Notifications.notifier.listeners_for('perform.active_job') - before)
        .each { |listener| ActiveSupport::Notifications.unsubscribe(listener) }
    end

    # A job the way the worker sees one it claimed: SolidQueue::ClaimedExecution#execute is what puts
    # the id there, and an inline job never has one.
    def claimed_job
      NoopJob.new.tap { |job| job.provider_job_id = 4242 }
    end

    # Runs the guard's own check, or the given block instead, with +running_jobs+ of the worker's
    # pool slots taken and +rss+ MB reported. Pass an array for +rss+ where the guard's two reads
    # differ, what the job ended on and what is left once it has collected; its last number answers
    # every read after it.
    # @return [Boolean] whether the guard stopped the worker
    def recycled?(worker, running_jobs: 1, rss: 2048, &action)
      action ||= -> { DataCycleCore::WorkerMemoryGuard.send(:recycle_if_over_limit, claimed_job) }
      DataCycleCore::WorkerMemoryGuard.instance_variable_set(:@worker, worker)
      DataCycleCore::WorkerMemoryGuard.instance_variable_set(:@limit, DataCycleCore.worker_max_memory)
      stopped = false
      readings = Array.wrap(rss)

      record_stop = lambda do
        stopped = true
        self.class.worker_stopped = true
      end

      worker.stub(:stop, record_stop) do
        DataCycleCore::WorkerMemoryGuard.stub(:rss_megabytes, -> { readings.many? ? readings.shift : readings.first }) do
          with_reserved_slots(worker, running_jobs, &action)
        end
      end

      stopped
    end

    def perform_as_claimed(job)
      ActiveJob::Base.execute(job.serialize.merge('provider_job_id' => 4242))
    end

    test 'stops a worker whose only job left it over the limit' do
      assert recycled?(build_worker)
    end

    test 'leaves a worker that stayed under the limit alone' do
      assert_not recycled?(build_worker, rss: 512)
    end

    # The RSS a job ends on still counts its garbage, and a freed large allocation goes back to the
    # OS: a peak that the collection gives back is not what the worker would carry into the next job.
    test 'leaves a worker whose peak the collection gave back alone' do
      assert_not recycled?(build_worker, rss: [2048, 512])
    end

    test 'stops a worker that is still over the limit once it has collected' do
      assert recycled?(build_worker, rss: [4096, 2048])
    end

    test 'waits while a sibling job is still running, which stopping would restart from the top' do
      assert_not recycled?(build_worker(threads: 2), running_jobs: 2)
      assert recycled?(build_worker(threads: 2), running_jobs: 1)
    end

    # Regression: the capacity test ran once, before the collection. A sibling finishing during
    # GC.start wakes the poller (Pool#post's on_idle), which claims and posts as many executions as
    # available_capacity reports, so a threaded worker had a fresh job to cut short by the time it
    # was stopped.
    test 'a job posted while the worker collects keeps it alive' do
      worker = build_worker(threads: 2)

      recycled = recycled?(worker) do
        GC.stub(:start, -> { worker.pool.send(:reserve_capacity!) }) do
          DataCycleCore::WorkerMemoryGuard.send(:recycle_if_over_limit, claimed_job)
        end
      end

      assert_not recycled
    end

    test 'stays inert where /proc/self/status cannot be read' do
      assert_not recycled?(build_worker, rss: nil)
    end

    test 'a supervised worker is stopped by the job it finishes' do
      worker = build_worker

      assert recycled?(worker) { supervising(worker) { perform_as_claimed(NoopJob.new) } }
    end

    # Regression: perform.active_job fires for an inline job too, and it holds no pool slot of its
    # own, so before the provider_job_id check the capacity test passed for it and the worker stopped
    # while its caller was still inside perform -- releasing the caller to run again from the top.
    test 'a job run inline inside the claimed one does not stop the worker mid perform' do
      worker = build_worker
      InliningJob.stopped_mid_perform = nil
      self.class.worker_stopped = false

      recycled?(worker) do
        supervising(worker) { perform_as_claimed(InliningJob.new) }
      end

      assert_not InliningJob.stopped_mid_perform
    end

    test 'a worker with no limit configured subscribes nothing' do
      DataCycleCore.worker_max_memory = 0
      worker = build_worker

      assert_not recycled?(worker) { supervising(worker) { perform_as_claimed(NoopJob.new) } }
    end

    # Regression: the subscription is process-global, and the suite is what calls supervise twice
    # (worker_pool_test.rb fires the start hooks by hand). A first subscriber left in place goes on
    # reading @worker and @limit, so the second call, subscribing nothing itself for want of a limit,
    # re-armed it at 0, where every RSS is over the limit. The test above only catches that once
    # something in the same process has supervised, which the run's file order decides.
    test 'a second supervise retires the subscriber the first one left' do
      DataCycleCore::WorkerMemoryGuard.supervise(build_worker)
      DataCycleCore.worker_max_memory = 0
      worker = build_worker

      assert_not recycled?(worker) { supervising(worker) { perform_as_claimed(NoopJob.new) } }
    end

    # See +DataCycleCore::WorkerMemoryGuard.forked?+: an async supervisor's workers are threads of the
    # process supervising them, and nothing there forks a replacement for one the guard stopped.
    test 'a worker nothing forked is not watched, because nothing would replace it' do
      [nil, ::Process.pid].each do |supervisor_pid|
        worker = build_worker(supervisor_pid:)

        assert_not recycled?(worker) { supervising(worker) { perform_as_claimed(NoopJob.new) } },
                   "supervisor pid #{supervisor_pid.inspect}"
      end
    end

    test 'reports this process resident set size in megabytes' do
      rss = DataCycleCore::WorkerMemoryGuard.rss_megabytes

      skip 'no /proc on this host' if rss.nil?

      assert_operator rss, :>, 0
    end
  end
end

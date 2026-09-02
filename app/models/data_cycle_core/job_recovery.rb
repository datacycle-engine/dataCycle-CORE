# frozen_string_literal: true

module DataCycleCore
  # Requeues jobs that were interrupted by something other than their own failure.
  #
  # SolidQueue covers the graceful path by itself: on shutdown the supervisor deregisters and
  # cascades to its supervisees (+SolidQueue::Process#deregister+), and destroying a worker row
  # releases that worker's claimed executions back to +ready+
  # (+SolidQueue::Process::Executor#release_all_claimed_executions+). Jobs interrupted by a deploy
  # therefore resume on their own, as long as the container's +stop_grace_period+ leaves the
  # supervisor enough time to get there — which is why +SolidQueue.shutdown_timeout+ is kept short.
  #
  # This is the safety net for the ungraceful path: SIGKILL, OOM or a host crash. There the worker
  # rows survive holding their claims, and the gem's own maintenance *fails* those jobs
  # (+ProcessPrunedError+) rather than resuming them. +retry_on+ never sees such a failure because
  # it happens outside +perform+, so nothing requeues them and the dashboard hides them behind its
  # +where.missing(:failed_execution)+ filters while the failed counter grows.
  #
  # Replaces the +Delayed::Job+ era +locked_by+/+locked_at+ reset, and is called from the same
  # place: the pre-run hook of a starting container, before the app serves traffic.
  module JobRecovery
    # Errors SolidQueue attributes to a job when the process running it went away.
    INTERRUPTED_BY = [
      'SolidQueue::Processes::ProcessPrunedError',
      'SolidQueue::Processes::ProcessMissingError',
      'SolidQueue::Processes::ProcessExitError'
    ].freeze

    class << self
      # Order matters: claims are released first so their concurrency keys count as held, then the
      # leftover locks go, and only then are the interrupted jobs requeued — a requeue re-runs
      # +SolidQueue::Job#dispatch+, which waits on the semaphore and would otherwise block itself.
      # @return [Hash{Symbol=>Integer}] number of rows handled per step
      def unlock
        {
          released_from_dead_processes: release_claims_of_dead_processes,
          released_orphaned_claims: release_orphaned_claims,
          cleared_locks: clear_orphaned_locks,
          requeued: requeue_interrupted
        }
      end

      # +dc:jobs:unlock+ runs from the pre-run hook of a starting container, before a fresh
      # installation has been migrated, and after +db:restore+ loaded a dump predating SolidQueue.
      # One table is enough to ask for: the gem creates all of them in a single migration.
      # @return [Boolean]
      def tables_exist?
        SolidQueue::Job.table_exists?
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
        false
      end

      private

      # Deregistering a dead process releases its claimed jobs back to +ready+, whereas
      # +SolidQueue::Process.prune+ would fail them. Only processes whose heartbeat stopped longer
      # than +process_alive_threshold+ ago are touched, so running workers keep their claims.
      def release_claims_of_dead_processes
        dead = SolidQueue::Process.prunable.to_a
        return 0 if dead.empty?

        released = SolidQueue::ClaimedExecution.where(process: dead).count
        dead.each(&:deregister)

        released
      end

      # Claims whose process row disappeared without running its callbacks.
      def release_orphaned_claims
        SolidQueue::ClaimedExecution.orphaned.count.tap do |count|
          SolidQueue::ClaimedExecution.orphaned.release_all if count.positive?
        end
      end

      # A job holds its semaphore from dispatch — the moment it becomes +ready+ — until it
      # finishes, so every live +ready+ or +claimed+ job is a legitimate holder. Blocked and
      # scheduled jobs are waiting for the lock rather than holding it, so a taken lock without a
      # holder belongs to a job that no longer exists.
      #
      # Only taken locks are considered: no job in core passes +limit:+ to +limits_concurrency+, so
      # a lock is taken exactly when its remaining value dropped below the default limit of 1.
      # Rows that are still available need no cleaning — a later +wait+ can use them as they are.
      #
      # The holders are asked for per semaphore row instead of being collected in Ruby first: this
      # runs on a host that just came back from a crash with its queue still full, which is the one
      # situation where that list is long enough to matter.
      #
      # The rows go in id ordered batches of 500, the statement shape SolidQueue's own concurrency
      # maintenance uses (+Semaphore.expired.in_batches(of: batch_size, &:delete_all)+). A web
      # restart runs this from the pre-run hook while the jobs container's dispatcher keeps sweeping,
      # and one unbatched +DELETE ... WHERE value < 1 AND NOT EXISTS (...)+ locks every row of the
      # table in whatever order its plan scans them, which need not be the id order of the batches
      # the dispatcher deletes — the two then deadlock over rows they both want. Each batch keeps the
      # +NOT EXISTS+ guard, so a lock re-acquired between the id lookup and the delete survives.
      def clear_orphaned_locks
        [SolidQueue::ReadyExecution, SolidQueue::ClaimedExecution]
          .reduce(SolidQueue::Semaphore.where(value: ...1)) { |scope, execution| scope.where.not(holder_exists(execution)) }
          .in_batches(of: 500)
          .delete_all
      end

      # Whether a job in the given state holds the lock of the semaphore row under examination.
      # @param execution [Class<SolidQueue::Execution>] the execution the job has to have to be live
      # @return [Arel::Nodes::Exists]
      def holder_exists(execution)
        SolidQueue::Job
          .where(id: execution.select(:job_id))
          .where(SolidQueue::Job.arel_table[:concurrency_key].eq(SolidQueue::Semaphore.arel_table[:key]))
          .arel.exists
      end

      # Batched for the same reason: +SolidQueue::FailedExecution#retry+ locks and requeues one row
      # per transaction anyway, so there is nothing to gain from holding the whole set in memory.
      def requeue_interrupted
        interrupted = SolidQueue::FailedExecution
          .where.not(error: nil)
          .where("solid_queue_failed_executions.error::jsonb ->> 'exception_class' IN (?)", INTERRUPTED_BY)

        requeued = 0
        interrupted.in_batches { |batch| requeued += batch.each(&:retry).size }

        requeued
      end
    end
  end
end

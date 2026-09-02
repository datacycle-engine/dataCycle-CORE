# frozen_string_literal: true

module DataCycleCore
  module JobExtensions
    # What a job can ask and do about its own row in the SolidQueue tables: whether another one like
    # it is already outstanding, and how to hold on to its concurrency lock while it runs.
    #
    # Everything here is about *this* job. Queue rows in general are reached through
    # +SolidQueue::Job+ and its scopes instead of through finders on the job class, which would read
    # as if they were scoped to that class while they never are, and would hand back queue rows
    # where a job is expected.
    module Persistence
      extend ActiveSupport::Concern

      # Extends the expiration time of the concurrency lock (semaphore) held by the
      # currently running job, as well as any blocked duplicates waiting on the same key.
      # Prevents the semaphore from expiring mid-run, which would otherwise allow a duplicate to
      # start concurrently. Driven by +with_extended_concurrency_lock+.
      # @return [void]
      def extend_concurrency_lock
        return if concurrency_key.nil?

        expires_at = concurrency_duration.from_now
        SolidQueue::Semaphore.where(key: concurrency_key).update_all(expires_at:)
        SolidQueue::BlockedExecution.where(concurrency_key:).update_all(expires_at:)
      end

      # Holds the concurrency lock for as long as the block runs, refreshing it on a timer.
      #
      # The refresh has to come from something that ticks on its own. Hanging it off log output
      # made correctness depend on log verbosity: a step that goes quiet — because it is waiting on
      # a slow API page, or because its info logging was switched off — let the lock expire, and
      # concurrency maintenance then released a second job for the same key to run alongside this
      # one. It also wrote two rows per log line.
      # @return [Object] whatever the block returns
      def with_extended_concurrency_lock
        return yield if concurrency_key.nil?

        timer = Concurrent::TimerTask.new(execution_interval: concurrency_duration / 3) do
          Rails.application.executor.wrap { extend_concurrency_lock }
        end
        timer.add_observer { |_, _, error| Rails.logger.error("could not extend the concurrency lock for #{concurrency_key}: #{error.message}") if error }
        timer.execute

        yield
      ensure
        timer&.shutdown
      end

      # Checks if a duplicate job with the same concurrency key is *waiting* on this one.
      # @return [Boolean] true if a blocked duplicate exists
      def duplicate_queued?
        return false if concurrency_key.nil?

        SolidQueue::BlockedExecution.exists?(expires_at: Time.current.., concurrency_key:)
      end

      # Checks if any live job already holds this concurrency key — the ready or claimed one that
      # took the semaphore included, not only a blocked duplicate.
      #
      # This is the check for +on_conflict: :discard+, where SolidQueue destroys the losing job at
      # dispatch and there is consequently never a blocked row to find.
      # @return [Boolean] true if a live job for the same key exists
      def duplicate_pending?
        return false if concurrency_key.nil?

        live_duplicates.exists?
      end

      # Checks if a duplicate job with matching class, arguments, and concurrency key is queued.
      #
      # This looks at the jobs table itself rather than only at blocked executions: the FIRST job
      # for a concurrency key acquires the semaphore at enqueue time and becomes *ready*, so a
      # blocked-execution-only check misses it and lets one redundant duplicate through.
      #
      # The comparison has to be built the way ActiveJob writes the row, which means going through
      # its private +serialize_arguments_if_needed+ — GlobalIds and the +_aj_+ wrappers are exactly
      # what distinguishes two argument lists here. A Rails upgrade that changes that method or the
      # shape it produces would not raise; the query would simply stop matching and duplicates would
      # queue up again, so +persistence_test.rb+ asserts the serialized shape as well as the match.
      # @return [Boolean] true if a duplicate with identical arguments exists
      def duplicate_queued_with_args?
        return false if concurrency_key.nil?

        live_duplicates
          .where(class_name: self.class.name)
          .exists?(["(solid_queue_jobs.arguments::jsonb -> 'arguments') = ?::jsonb", serialize_arguments_if_needed(arguments).to_json])
      end

      private

      # Live queue rows for this job's concurrency key, minus the job itself: callers normally ask
      # before enqueueing, but this stays correct when a persisted job asks.
      # @return [ActiveRecord::Relation<SolidQueue::Job>]
      def live_duplicates
        scope = SolidQueue::Job.live.where(concurrency_key:)
        scope = scope.where.not(id: provider_job_id) if provider_job_id.present?

        scope
      end
    end
  end
end

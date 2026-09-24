# frozen_string_literal: true

module DataCycleCore
  # Ends a SolidQueue worker process once a job has left it too big, so its memory goes back to the
  # OS instead of staying with the worker for the rest of its life.
  #
  # What a job leaves behind is Ruby's own heap: the GC frees the slots but keeps the pages, so an
  # import that churned millions of small objects holds that RSS for every job that follows. Measured
  # on the app image, 2 M short-lived hashes leave 724 MB, still 665 MB after a full GC, so nothing
  # short of ending the process gives those pages back.
  # +SolidQueue::ForkSupervisor#check_and_replace_terminated_processes+ forks a replacement for any
  # worker that exits, so the recycle costs one boot and nothing else.
  #
  # Jobs still claimed when the worker exits are released back to +ready+ rather than failed
  # (+SolidQueue::Process::Executor#release_all_claimed_executions+, see +DataCycleCore::JobRecovery+),
  # but they would restart from the top, so the guard waits until the job that just finished is the
  # only one the pool still holds a slot for. That job has yet to record itself as finished, and gets
  # the +config.solid_queue.shutdown_timeout+ of 5 seconds to do so, the same budget a deploy gives it.
  module WorkerMemoryGuard
    STATUS_PATH = '/proc/self/status'
    RSS_PREFIX = 'VmRSS:'

    class << self
      # Starts watching the worker this process is, if a limit is configured. Called from the
      # +SolidQueue.on_worker_start+ hook, and the one place that decides whether the guard runs at
      # all, so a worker that subscribed always has a limit to compare against.
      #
      # A second call replaces the first subscriber rather than stacking one on top of it: +@worker+
      # and +@limit+ are single slots, so one left behind would go on asking about a worker that is
      # gone, against whatever limit the later call read (0 included, where every RSS is over the
      # limit). test/models/worker_pool_test.rb turned that up, firing the start hooks by hand.
      # @param worker [SolidQueue::Worker]
      # @return [void]
      def supervise(worker)
        @limit = DataCycleCore.worker_max_memory.to_i
        ActiveSupport::Notifications.unsubscribe(@subscriber) unless @subscriber.nil?
        @subscriber = @worker = nil
        return if @limit.zero?

        unless forked?(worker)
          SolidQueue.logger.warn("[WorkerMemoryGuard] #{worker.name} is not a forked process, so nothing would replace it: leaving its memory alone")
          return
        end

        @worker = worker

        # glibc keeps a freed peak in its arenas, so without jemalloc the +GC.start+ in
        # +recycle_if_over_limit+ cannot take a worker back under the limit and every peak buys a boot.
        SolidQueue.logger.warn("[WorkerMemoryGuard] #{@worker.name} does not run on jemalloc, so a collected peak stays with it: rebuild the base ruby image") unless DataCycleCore::Jemalloc.available?

        # +perform.active_job+ fires for a failed job as well as a successful one, which matters
        # here: a download that runs out of memory and raises has still grown the worker.
        @subscriber = ActiveSupport::Notifications.subscribe('perform.active_job') { |event| recycle_if_over_limit(event.payload[:job]) }
      end

      # /proc reports VmRSS in kB and exists only on Linux, so a developer running the workers on a
      # macOS host gets nil here and the guard stays inert.
      # @return [Integer, nil] this process' resident set size in MB
      def rss_megabytes
        line = File.foreach(STATUS_PATH).find { |l| l.start_with?(RSS_PREFIX) }
        return if line.nil?

        line.split.second.to_i / 1024
      rescue SystemCallError
        nil
      end

      private

      # Whether the supervisor forked this worker, the one case in which ending it gives the queues
      # it served back: +check_and_replace_terminated_processes+ is empty on +SolidQueue::Supervisor+
      # and overridden only by +ForkSupervisor+, so a worker stopped under the AsyncSupervisor stays
      # stopped until that process restarts. Asked of the +SolidQueue::Process+ record the supervisor
      # registered the worker against, whose pid is this process' own for an async worker (a thread of
      # the one supervising it) and its parent's for a forked one. +Runnable#mode+ answers directly
      # and is private, and SOLID_QUEUE_SUPERVISOR_MODE misses what puma's `solid_queue_mode` passes.
      # @param worker [SolidQueue::Worker]
      # @return [Boolean]
      def forked?(worker)
        worker.supervisor.present? && worker.supervisor.pid != ::Process.pid
      end

      # Runs in the job's own thread, inside the +perform.active_job+ instrumentation, so the job
      # that just finished still holds its pool slot. The pool is asked again after the +GC.start+
      # because a sibling finishing during it wakes the poller (+Pool#post+'s +on_idle+), which posts
      # as many executions as +available_capacity+ reports.
      #
      # Which job finished is the whole question, because +perform_now+ emits this event too: a job
      # run inside another one (+ImportHelper.perform_job+ with +run_now=true+, an export whose
      # webhooks are synchronous) would otherwise stop the worker while its caller is still inside
      # +perform+, and the caller would be released and re-dispatched from the top. Only the claimed
      # job carries a +provider_job_id+, merged into the payload by
      # +SolidQueue::ClaimedExecution#execute+; a pool slot cannot tell the two apart, since an inline
      # job takes none and the capacity check passes for it as well.
      #
      # The limit is compared twice because the RSS a job ends on is not what the worker retains: its
      # garbage is still uncollected, and a large allocation goes back to the OS as soon as the GC
      # frees it (jemalloc's decay purge, see +DataCycleCore::Jemalloc+). Measured on the app image
      # with 1.5 GB of strings dropped by the job: 1806 MB before the +GC.start+, 328 MB after it.
      #
      # Nothing in this path may raise, or it would surface as an +InstrumentationSubscriberError+ out
      # of the job that just succeeded: +rss_megabytes+ answers nil instead, and
      # +SolidQueue::Processes::Runnable#stop+ only flips a flag and wakes the worker's self-pipe.
      # @param job [ActiveJob::Base] the job whose perform.active_job just closed
      # @return [void]
      def recycle_if_over_limit(job)
        return if @worker.nil? || job&.provider_job_id.nil?
        return unless alone_in_pool?

        peak = rss_over_limit
        return if peak.nil?

        GC.start
        rss = rss_over_limit
        return if rss.nil? || !alone_in_pool?

        SolidQueue.logger.info("[WorkerMemoryGuard] stopping #{@worker.name} at #{rss} MB (#{peak} MB before collecting, limit #{@limit} MB); the supervisor replaces it")

        @worker.stop
      end

      # @return [Boolean] whether the job that just finished is the only one the worker's pool holds
      #   a slot for
      def alone_in_pool?
        @worker.pool.available_capacity == @worker.pool.size - 1
      end

      # @return [Integer, nil] this process' RSS in MB while it exceeds the limit, nil below it and
      #   nil wherever +rss_megabytes+ cannot read one
      def rss_over_limit
        rss = rss_megabytes

        rss if !rss.nil? && rss > @limit
      end
    end
  end
end

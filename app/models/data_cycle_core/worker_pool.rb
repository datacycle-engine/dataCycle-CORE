# frozen_string_literal: true

module DataCycleCore
  class WorkerPool
    # Connections a SolidQueue worker process keeps for itself, on top of what its jobs use: the
    # poller that claims executions, and the heartbeat that keeps its SolidQueue::Process row alive.
    RESERVED_CONNECTIONS = 2

    # Connections to keep clear for a single job before it opens a pool at all. One is held for real
    # -- the job's own thread, whenever it is inside a transaction. The second is headroom rather
    # than a checkout: a query outside a transaction leases a connection only for its own duration,
    # so the concurrency-lock timer owns nothing between ticks
    # (JobExtensions::Persistence#with_extended_concurrency_lock) and needs one for a few
    # milliseconds every duration/3. Letting it compete for the last connection is what this buys
    # off -- it would wait out the checkout timeout, the semaphore would expire, and a duplicate job
    # would be free to start alongside this one, which is the failure that timer exists to prevent.
    RESERVED_PER_JOB = 2

    attr_reader :queue, :num_workers

    def initialize(num_workers = nil)
      @queue = []
      @num_workers = num_workers || default_num_workers
      @pool = Concurrent::FixedThreadPool.new(@num_workers) if @num_workers&.>(1)
    end

    # How many threads a pool may open without exhausting the connection pool of the process it runs
    # in. Every thread checks out a connection of its own (see +append+), so this has to fit into
    # what is left of the pool once every job running alongside this one has taken its share.
    #
    # Under delayed_job the share was the whole pool: one process ran one job, and half the pool was
    # headroom enough. A SolidQueue worker runs +threads+ jobs in one process instead, each building
    # a pool of its own, so the same +size / 2+ overcommits the pool by a multiple of the thread
    # count and every one of those threads then waits out its checkout timeout. Dividing by the
    # concurrency first keeps the old number wherever jobs still run one at a time -- the web
    # process, rake tasks, a single-threaded worker -- and shrinks it everywhere else.
    #
    # A result of 1 is always safe: +initialize+ opens no pool for it, so the block runs on the
    # calling thread and reuses the connection that thread already holds.
    # @return [Integer] number of threads, at least 1
    def self.default_num_workers
      return 1 if Rails.env.test? # avoid concurrency in tests to prevent issues with database transactions

      pool_size = ActiveRecord::Base.connection_pool.size
      # clamped rather than trusted: the value comes from a worker's thread count via the
      # SolidQueue hook, and a zero would take the whole sizing down with a ZeroDivisionError
      per_job_budget = (pool_size - RESERVED_CONNECTIONS) / DataCycleCore.concurrent_job_threads.to_i.clamp(1..)

      [pool_size / 2, per_job_budget - RESERVED_PER_JOB].min.clamp(1..)
    end

    delegate :default_num_workers, to: :class

    def append_without_db_connection(&)
      if @pool
        @queue << Concurrent::Promises.future_on(@pool, &)
      else
        yield
      end
    end

    def append(&)
      append_without_db_connection do
        ActiveRecord::Base.connection_pool.with_connection(&)
      end
    end
    alias << append

    def wait!
      @queue.each(&:wait!) if @pool
    rescue DataCycleCore::Error::Api::TimeOutError, Timeout::Error => e
      @pool&.kill

      raise e
    ensure
      @pool&.shutdown
    end
  end
end

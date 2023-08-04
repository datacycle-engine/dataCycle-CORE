# frozen_string_literal: true

module DataCycleCore
  class WorkerPool
    attr_reader :queue

    def initialize(num_workers)
      @queue = []
      @pool = Concurrent::FixedThreadPool.new(num_workers) if num_workers&.>(1)
    end

    def append_without_db_connection(&)
      if @pool
        @queue << Concurrent::Promise.execute({ executor: @pool }, &)
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
    ensure
      @pool&.shutdown
    end
  end
end

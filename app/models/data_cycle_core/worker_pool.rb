# frozen_string_literal: true

module DataCycleCore
  class WorkerPool
    def initialize(num_workers)
      @queue = []
      @workers = Concurrent::FixedThreadPool.new(num_workers) if num_workers&.>(1)
    end

    def append_without_db_connection(&block)
      if @workers
        @queue << Concurrent::Promise.execute({ executor: @workers }, &block)
      else
        yield
      end
    end

    def append(&block)
      append_without_db_connection do
        ActiveRecord::Base.connection_pool.with_connection(&block)
      end
    end
    alias << append

    def wait!
      @queue.each(&:wait!) if @workers
    end
  end
end

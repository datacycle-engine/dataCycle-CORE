# frozen_string_literal: true

module DataCycleCore
  class WorkerPool
    def initialize(num_workers)
      @queue = []
      @workers = Concurrent::FixedThreadPool.new(num_workers) if num_workers&.>(1)
    end

    def <<(&block)
      append(&block)
    end

    def append(&block)
      if @workers
        @queue << Concurrent::Promise.execute({ executor: @workers }, &block)
      else
        yield
      end
    end

    def wait
      @queue.each(&:wait!) if @workers
    end
  end
end

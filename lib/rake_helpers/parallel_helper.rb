# frozen_string_literal: true

class ParallelHelper
  class << self
    def run_in_parallel(futures, pool, &block)
      if pool.nil?
        yield
      else
        futures << Concurrent::Promise.execute({ executor: pool }) do
          ActiveRecord::Base.connection_pool.with_connection(&block)
        end
      end
    end
  end
end

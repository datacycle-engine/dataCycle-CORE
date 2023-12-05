# frozen_string_literal: true

class ParallelHelper
  class << self
    def run_in_parallel(futures, pool, &)
      if pool.nil?
        yield
      else
        futures << Concurrent::Promise.execute({ executor: pool }) do
          ActiveRecord::Base.connection_pool.with_connection(&)
        end
      end
    end
  end
end

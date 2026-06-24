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

    # required for e.g. async_count or async_total_count to prevent error: Can't perform asynchronous queries without a query session (ActiveRecord::ActiveRecordError) in rake tasks
    def with_asynchronous_queries_session(&)
      async_queries_session = setup_asynchronous_queries_session
      yield
    ensure
      ActiveRecord::Base.asynchronous_queries_tracker.finalize_session(true) if async_queries_session
    end

    def setup_asynchronous_queries_session
      ActiveRecord::Base.asynchronous_queries_tracker.current_session
      nil
    rescue ActiveRecord::ActiveRecordError
      ActiveRecord::Base.asynchronous_queries_tracker.start_session
    end
  end
end

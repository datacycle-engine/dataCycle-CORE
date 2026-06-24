# frozen_string_literal: true

require 'test_helper'
require 'rake_helpers/parallel_helper'

module DataCycleCore
  class ParallelHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'run_in_parallel yields directly when no pool is given' do
      futures = []

      result = ParallelHelper.run_in_parallel(futures, nil) { 42 }

      assert_equal 42, result
      assert_empty futures
    end

    test 'run_in_parallel schedules the block on the pool when given' do
      pool = Concurrent::FixedThreadPool.new(1)
      futures = []

      ParallelHelper.run_in_parallel(futures, pool) { DataCycleCore::Thing.count }

      assert_equal 1, futures.size
      assert_kind_of Integer, futures.first.value!
    ensure
      pool&.shutdown
      pool&.wait_for_termination(5)
    end

    test 'with_asynchronous_queries_session starts a session when none exists' do
      tracker = ActiveRecord::Base.asynchronous_queries_tracker
      yielded = false

      tracker.stub(:current_session, ->(*) { raise ActiveRecord::ActiveRecordError }) do
        tracker.stub(:start_session, :session) do
          tracker.stub(:finalize_session, nil) do
            ParallelHelper.with_asynchronous_queries_session { yielded = true }
          end
        end
      end

      assert yielded
    end

    test 'with_asynchronous_queries_session reuses an existing session' do
      tracker = ActiveRecord::Base.asynchronous_queries_tracker
      yielded = false

      tracker.stub(:current_session, :existing) do
        ParallelHelper.with_asynchronous_queries_session { yielded = true }
      end

      assert yielded
    end
  end
end

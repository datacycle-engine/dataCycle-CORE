# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WorkerPoolTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # The sizes the pool is asked to fit into, as (connection pool, jobs running at once) pairs, and
    # what it may open for each. Every one of them has to leave the process able to run all of its
    # jobs at the same time -- see the invariant below, which is what the numbers are derived from.
    SIZINGS = [
      [15, 1, 7], # the default pool (PUMA_MAX_THREADS x 3) in a process that runs one job at a time
      [15, 3, 2], # ... and what is left of it for each thread of a 3-thread SolidQueue worker
      [10, 1, 5], # what a single-threaded process took while the pool was still x 2: half of it
      [10, 2, 2],
      [10, 3, 1], # a pool too tight to share: every job falls back to running its work inline
      [24, 3, 5], # a raised DB_POOL_SIZE buys a multi-threaded worker more of its parallelism back
      [30, 5, 3],
      [6, 1, 2]
    ].freeze

    # Runs +default_num_workers+ against a given process shape. It bails out early in the test
    # environment, so the environment has to be stubbed along with the two inputs it reads.
    def num_workers_for(pool_size, concurrent_job_threads)
      previous = DataCycleCore.concurrent_job_threads
      DataCycleCore.concurrent_job_threads = concurrent_job_threads

      Rails.stub(:env, ActiveSupport::StringInquirer.new('production')) do
        ActiveRecord::Base.connection_pool.stub(:size, pool_size) do
          DataCycleCore::WorkerPool.default_num_workers
        end
      end
    ensure
      DataCycleCore.concurrent_job_threads = previous
    end

    test 'the number of workers is the share of the connection pool this job may spend' do
      SIZINGS.each do |pool_size, concurrent_job_threads, expected|
        assert_equal expected, num_workers_for(pool_size, concurrent_job_threads),
                     "pool of #{pool_size} split between #{concurrent_job_threads} jobs"
      end
    end

    # The reason the class exists in this shape: every worker thread checks out a connection of its
    # own, so all of the jobs a process runs at once, with the pools they open, have to fit into the
    # one connection pool they share. Sizing that off the raw pool size -- correct while a process
    # ran a single job -- overcommits it by a multiple of the thread count on a SolidQueue worker,
    # and every thread over the limit then waits out its checkout timeout instead of working.
    test 'a process can run all of its jobs at once without exhausting the connection pool' do
      SIZINGS.each do |pool_size, concurrent_job_threads, _expected|
        num_workers = num_workers_for(pool_size, concurrent_job_threads)
        # a pool of one opens no threads at all, so it costs the job nothing on top of its own
        per_job = DataCycleCore::WorkerPool::RESERVED_PER_JOB + (num_workers > 1 ? num_workers : 0)
        needed = (concurrent_job_threads * per_job) + DataCycleCore::WorkerPool::RESERVED_CONNECTIONS

        assert_operator needed, :<=, pool_size,
                        "#{concurrent_job_threads} jobs x #{num_workers} workers need #{needed} of #{pool_size} connections"
      end
    end

    test 'a connection pool too small for the configured concurrency still leaves one worker' do
      assert_equal 1, num_workers_for(4, 8)
    end

    # the count is published by a hook reading a gem's thread pool, so it is not ours to trust
    test 'a nonsensical job concurrency does not take the sizing down with it' do
      assert_equal 7, num_workers_for(15, 0)
      assert_equal 7, num_workers_for(15, nil)
    end

    test 'tests run without concurrency, to keep jobs inside the test transaction' do
      assert_equal 1, DataCycleCore::WorkerPool.default_num_workers
    end

    # The sizing above is only correct if something tells it how many jobs the process runs at once,
    # which for a SolidQueue worker is the hook in +config/initializers/solid_queue.rb+. A version of
    # SolidQueue that stops handing the worker to its start hooks, or stops exposing the thread pool
    # it was configured with, would leave the count at 1 and quietly restore the overcommit -- so
    # assert the wiring itself rather than only the arithmetic it feeds.
    test 'a SolidQueue worker publishes how many jobs it runs at once' do
      previous = DataCycleCore.concurrent_job_threads
      worker = SolidQueue::Worker.new(queues: 'background', threads: 4)

      SolidQueue::Worker.lifecycle_hooks[:start].each { |hook| hook.call(worker) }

      assert_equal 4, DataCycleCore.concurrent_job_threads
    ensure
      DataCycleCore.concurrent_job_threads = previous
    end

    test 'a single worker runs on the calling thread, taking no connection of its own' do
      pool = DataCycleCore::WorkerPool.new(1)
      thread = nil

      pool.append { thread = Thread.current }
      pool.wait!

      assert_equal Thread.current, thread
    end

    test 'more than one worker schedules on a thread pool' do
      pool = DataCycleCore::WorkerPool.new(2)
      pool.append_without_db_connection { 1 + 1 }

      assert_equal 1, pool.queue.size

      pool.wait!
    end

    test 'a timeout in one worker is re-raised after the pool is killed' do
      pool = DataCycleCore::WorkerPool.new(2)
      failing = Object.new
      failing.define_singleton_method(:wait!) { raise Timeout::Error }
      pool.instance_variable_set(:@queue, [failing])

      assert_raises(Timeout::Error) { pool.wait! }
    end
  end
end

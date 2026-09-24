# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class JemallocTest < DataCycleCore::TestCases::ActiveSupportTestCase
    setup do
      skip 'this process does not run on jemalloc' unless DataCycleCore::Jemalloc.available?
    end

    # +exit!+ because a child that leaves through Process.fork's own exit runs the parent's at_exit
    # handlers, SimpleCov's among them: it writes the seven lines the child covered as a result of
    # its own, named "Minitest (subprocess: 1)", which the report merges and coverage/.resultset.json
    # carries into later runs.
    # @return [Object] whatever the block answered in a forked child
    def in_fork
      read, write = IO.pipe
      pid = Process.fork do
        read.close
        Marshal.dump(yield, write)
        write.close
        exit!(0)
      end
      write.close
      result = read.read
      Process.waitpid(pid)
      read.close

      Marshal.load(result) # rubocop:disable Security/MarshalLoad
    end

    test 'the decay purge runs in this process' do
      assert_predicate DataCycleCore::Jemalloc, :background_thread?
    end

    # jemalloc turns the background thread off in every forked child regardless of the parent, so
    # without the ForkTracker hook in config/initializers/jemalloc.rb this answers false, and every
    # SolidQueue worker, puma worker and per-page importer fork would run with the purge off.
    test 'a forked child keeps the decay purge' do
      assert(in_fork { DataCycleCore::Jemalloc.background_thread? })
    end

    test 'turning it on is idempotent' do
      assert_equal 0, DataCycleCore::Jemalloc.enable_background_thread!
      assert_predicate DataCycleCore::Jemalloc, :background_thread?
    end
  end
end

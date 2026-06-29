# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the Console import/export logger - a thin wrapper around puts. Output
  # is captured so it does not pollute the test log. (#info is left out: it references
  # an uninitialised @log and would raise - a pre-existing dead branch.)
  class GenericLoggerConsoleCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def logger
      DataCycleCore::Generic::Logger::Console.new('import')
    end

    test 'preparing_phase and phase_started print the label with and without a total' do
      out, = capture_io do
        logger.preparing_phase('my_phase')
        logger.phase_started('my_phase')
        logger.phase_started('my_phase', 5)
      end

      assert_match 'Preparing', out
      assert_match '(5 items)', out
    end

    test 'error prints the matching variant for each title/id combination' do
      out, = capture_io do
        logger.error('Title', 1, { 'a' => 1 }, 'boom')
        logger.error('Title', nil, nil, 'boom')
        logger.error(nil, 2, nil, 'boom')
        logger.error(nil, nil, nil, 'boom')
      end

      assert_match 'Error importing "Title (#1)"', out
      assert_match 'DATA', out
    end

    test 'item_processed is a no-op and phase_finished prints DONE' do
      out, = capture_io do
        logger.item_processed('title', 1, 1, 1)
        logger.phase_finished('my_phase', 5)
      end

      assert_match '[DONE]', out
    end
  end
end

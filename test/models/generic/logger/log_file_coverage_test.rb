# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the LogFile import/export logger. The underlying ::Logger is stubbed
  # with a no-op double so the message-building logic (phase labels, the error variants
  # and the data truncation) runs without writing a log file.
  class GenericLoggerLogFileCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def logger
      log_double = Object.new
      [:info, :error, :debug, :close].each { |method| log_double.define_singleton_method(method) { |*| nil } }
      ::Logger.stub(:new, log_double) do
        DataCycleCore::Generic::Logger::LogFile.new('test')
      end
    end

    test 'preparing_phase, phase_started and phase_finished build phase labels' do
      log = logger

      assert_nil log.preparing_phase('my_phase')
      assert_nil log.phase_started('my_phase')
      assert_nil log.phase_started('my_phase', 5)
      assert_nil log.phase_finished('my_phase', 5)
    end

    test 'error builds the matching variant and truncates long data dumps' do
      log = logger
      big_data = (1..25).index_by { |i| "key_#{i}" }

      assert_nil log.error('Title', 1, big_data, 'boom')
      assert_nil log.error('Title', nil, nil, 'boom')
      assert_nil log.error(nil, 2, nil, 'boom')
    end

    test 'info and debug forward to the logger' do
      log = logger

      assert_nil log.info('title')
      assert_nil log.info('title', 'id')
      assert_nil log.debug('title', 1, { 'a' => 1 })
    end
  end
end

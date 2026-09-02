# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Loggers
    # Coverage for InstrumentationLogger#dc_log's error-message builder — the format the
    # download/import log subscribers (config/initializers/instrumentation.rb) write for every failed
    # phase. Logging is captured by swapping in a StringIO device, and broadcast_line is stubbed away
    # so no Turbo stream is emitted.
    class InstrumentationLoggerTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # Stand-in for a message that does not name its own type. A constant because test 2 strips it
      # back out of the logged line — a drifted second copy would strip nothing and still pass.
      OPAQUE_MESSAGE = 'boom'

      class OpaqueMessageError < StandardError
        def initialize
          super(OPAQUE_MESSAGE)
        end
      end

      # carries no message at all, so `Exception#to_s` falls back to the class name
      class NoMessageError < StandardError; end

      def capturing_logger(type: 'import')
        device = StringIO.new
        logger = DataCycleCore::Loggers::InstrumentationLogger.new(type:)
        logger.reopen(device)
        logger.define_singleton_method(:broadcast_line) { |_severity, _message| nil }

        [logger, device]
      end

      def raised(error_class)
        raise error_class
      rescue StandardError => e
        e
      end

      test 'error messages name the exception class next to its message' do
        logger, device = capturing_logger
        exception = raised(OpaqueMessageError)

        logger.dc_log(:error, { step_label: 'import step', exception:, external_system: nil })

        assert_includes device.string, '[I] import step ... [FAILED]'
        assert_includes device.string, 'Exception: DataCycleCore::Loggers::InstrumentationLoggerTest::OpaqueMessageError:'
        assert_includes device.string, OPAQUE_MESSAGE
      end

      test 'the class name is what identifies an error whose message is not diagnostic' do
        logger, device = capturing_logger
        exception = raised(OpaqueMessageError)

        logger.dc_log(:error, { step_label: 'import step', exception:, external_system: nil })
        logged = device.string

        # the point of the class name: strip the message and the line still names what failed. Before
        # the class name was logged, stripping the message left nothing diagnostic.
        without_message = logged.sub(OPAQUE_MESSAGE, '')

        assert_includes without_message, 'OpaqueMessageError'
      end

      test 'an exception that was never raised is logged without a backtrace' do
        logger, device = capturing_logger

        logger.dc_log(:error, { step_label: 'import step', exception: OpaqueMessageError.new, external_system: nil })

        assert_includes device.string, 'Exception: DataCycleCore::Loggers::InstrumentationLoggerTest::OpaqueMessageError:'
        assert_includes device.string, 'Backtrace: )'
      end

      test 'an exception carrying no message is not named twice' do
        logger, device = capturing_logger

        logger.dc_log(:error, { step_label: 'import step', exception: raised(NoMessageError), external_system: nil })

        assert_includes device.string, 'Exception: DataCycleCore::Loggers::InstrumentationLoggerTest::NoMessageError,'
        assert_not_includes device.string, 'NoMessageError: DataCycleCore::Loggers::InstrumentationLoggerTest::NoMessageError'
      end

      test 'an explicit message is logged unchanged, without the exception decoration' do
        logger, device = capturing_logger

        logger.dc_log(:error, { message: 'plain failure', exception: raised(OpaqueMessageError) })

        assert_includes device.string, 'plain failure'
        assert_not_includes device.string, 'Exception:'
      end
    end
  end
end

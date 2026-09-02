# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the Instrumentation logger - the message-building branches of the
  # phase/info/warning/error/debug helpers. ActiveSupport::Notifications.instrument is
  # stubbed to a no-op so the messages are built without emitting real events.
  class GenericLoggerInstrumentationCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def logger
      DataCycleCore::Generic::Logger::Instrumentation.new('import')
    end

    def content_double(id: 'content-1')
      content = Object.new
      content.define_singleton_method(:id) { id }
      content
    end

    test 'phase/info/warning/error/debug helpers build messages and instrument' do
      ActiveSupport::Notifications.stub(:instrument, nil) do
        log = logger

        assert_nil log.preparing_phase('my_phase')
        assert_nil log.warning('label', 'text', 'id-1')
        assert_nil log.primary_key_changed('label', content_double, ['old', 'new'])
        assert_nil log.error(nil, 5, nil, 'boom')   # id-only branch
        assert_nil log.error(nil, nil, nil, 'boom') # generic branch
        assert_nil log.debug('title', 1, { 'a' => 1 })
        assert_nil log.item_failed(StandardError.new('boom'), nil, 'label', 'ext-1', 'step')
      end
    end

    # item_failed takes its channel as an argument, so it is not download-only. The subscriber in
    # config/initializers/instrumentation.rb has to file the line under the kind that emitted it,
    # the way the job_failed subscriber next to it does -- a hardcoded 'download' wrote an
    # import-side call into the download log and broadcast it as a download event.
    test 'item_failed is logged under the kind of the logger that emitted it' do
      types = []

      DataCycleCore::Loggers::InstrumentationLogger.stub(:with_logger, ->(type:, &_block) { types << type }) do
        logger.item_failed(StandardError.new('boom'), nil, 'label', 'ext-1', 'step')
        DataCycleCore::Generic::Logger::Instrumentation.new('download')
          .item_failed(StandardError.new('boom'), nil, 'label', 'ext-2', 'step')
      end

      assert_equal ['import', 'download'], types
    end
  end
end

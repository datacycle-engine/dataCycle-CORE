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
      end
    end
  end
end

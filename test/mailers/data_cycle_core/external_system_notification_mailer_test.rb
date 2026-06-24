# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ExternalSystemNotificationMailerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'error_notify builds a failure notification mail' do
      external_system = Object.new
      external_system.define_singleton_method(:name) { 'ExternalSys' }

      mail = DataCycleCore::ExternalSystemNotificationMailer.error_notify(['ops@example.com'], 'import', external_system, 'boom', ['a.rb:1'])

      assert_equal ['ops@example.com'], mail.to
      assert_equal 'ExternalSys - import failed multiple times', mail.subject
    end

    test 'error_notify does nothing without a mailing list' do
      mail = DataCycleCore::ExternalSystemNotificationMailer.error_notify([], 'import', nil, 'boom', [])

      assert_nil mail.message.subject
    end

    test 'error_notify does nothing without a type' do
      mail = DataCycleCore::ExternalSystemNotificationMailer.error_notify(['ops@example.com'], nil, nil, 'boom', [])

      assert_nil mail.message.subject
    end
  end
end

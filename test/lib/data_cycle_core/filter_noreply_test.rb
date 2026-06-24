# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class FilterNoreplyTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'noreply? matches the expected patterns' do
      assert DataCycleCore::FilterNoreply.noreply?('noreply@example.com')
      assert DataCycleCore::FilterNoreply.noreply?('no-reply@example.com')
      assert DataCycleCore::FilterNoreply.noreply?('no_reply@example.com')
      assert DataCycleCore::FilterNoreply.noreply?('NoReply@example.com')
      assert DataCycleCore::FilterNoreply.noreply?('donotreply@example.com')

      assert_not DataCycleCore::FilterNoreply.noreply?('user@example.com')
      assert_not DataCycleCore::FilterNoreply.noreply?(nil)
    end

    test 'remove_noreply rejects all noreply addresses' do
      assert_equal ['user@example.com'], DataCycleCore::FilterNoreply.remove_noreply(['noreply@example.com', 'user@example.com'])
      assert_equal ['user@example.com'], DataCycleCore::FilterNoreply.remove_noreply('user@example.com')
    end

    test 'delivering_email keeps real recipients and stays deliverable' do
      message = Mail.new(to: ['noreply@example.com', 'user@example.com'], cc: ['donotreply@example.com'])
      message.perform_deliveries = true

      DataCycleCore::FilterNoreply.delivering_email(message)

      assert_equal ['user@example.com'], message.to
      assert_equal [], Array.wrap(message.cc)
      assert message.perform_deliveries
    end

    test 'delivering_email disables delivery when no recipients remain' do
      message = Mail.new(to: ['noreply@example.com'])
      message.perform_deliveries = true

      DataCycleCore::FilterNoreply.delivering_email(message)

      assert_equal [], Array.wrap(message.to)
      assert_not message.perform_deliveries
      assert DataCycleCore::FilterNoreply.no_recipients_left?(message)
    end
  end
end

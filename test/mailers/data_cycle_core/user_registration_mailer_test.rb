# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserRegistrationMailerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'notify builds a registration notification mail' do
      new_user = User.find_by(email: 'guest@datacycle.at')

      mail = DataCycleCore::UserRegistrationMailer.notify(['admin@datacycle.at'], new_user)

      assert_equal ['admin@datacycle.at'], mail.to
      assert_predicate mail.subject, :present?
    end

    test 'notify does nothing without recipients' do
      new_user = User.find_by(email: 'guest@datacycle.at')

      mail = DataCycleCore::UserRegistrationMailer.notify([], new_user)

      assert_nil mail.message.subject
    end
  end
end

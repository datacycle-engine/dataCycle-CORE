# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserApiMailerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'notify builds an api user notification mail' do
      new_user = User.find_by(email: 'guest@datacycle.at')

      mail = DataCycleCore::UserApiMailer.notify(['admin@datacycle.at'], new_user)

      assert_equal ['admin@datacycle.at'], mail.to
      assert_predicate mail.subject, :present?
    end

    test 'notify does nothing without recipients' do
      new_user = User.find_by(email: 'guest@datacycle.at')

      mail = DataCycleCore::UserApiMailer.notify([], new_user)

      assert_nil mail.message.subject
    end

    test 'notify_confirmed builds an unlocked notification mail' do
      user = User.find_by(email: 'guest@datacycle.at')

      mail = DataCycleCore::UserApiMailer.notify_confirmed(user)

      assert_equal [user.email], mail.to
      assert_predicate mail.subject, :present?
    end

    test 'notify_confirmed does nothing for a blank user' do
      mail = DataCycleCore::UserApiMailer.notify_confirmed(nil)

      assert_nil mail.message.subject
    end
  end
end

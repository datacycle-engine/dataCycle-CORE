# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ReleasableSubscriptionMailerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'ReleasableMailerArticle' })
    end

    test 'notify builds a finalized subscription mail' do
      mail = DataCycleCore::ReleasableSubscriptionMailer.notify(@user, [@content.id])

      assert_equal [@user.email], mail.to
      assert_predicate mail.subject, :present?
    end

    test 'remind_receiver builds a reminder mail' do
      mail = DataCycleCore::ReleasableSubscriptionMailer.remind_receiver(@user, [])

      assert_equal [@user.email], mail.to
      assert_predicate mail.subject, :present?
    end
  end
end

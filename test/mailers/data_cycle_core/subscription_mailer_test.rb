# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SubscriptionMailerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'SubscriptionMailerArticle' })
      @watch_list = DataCycleCore::WatchList.create!(full_path: 'SubscriptionMailerWatchList', user: @user)
    end

    test 'notify builds a changed subscription mail' do
      mail = DataCycleCore::SubscriptionMailer.notify(@user, [@content.id])

      assert_equal [@user.email], mail.to
      assert_predicate mail.subject, :present?
    end

    test 'notify_changed_watch_list_items builds a watch list digest mail' do
      changed_items = { @watch_list.id => [{ user_id: @user.id, id: @content.id, type: 'add' }] }

      mail = DataCycleCore::SubscriptionMailer.notify_changed_watch_list_items(@user, changed_items)

      assert_equal [@user.email], mail.to
      assert_predicate mail.subject, :present?
    end
  end
end

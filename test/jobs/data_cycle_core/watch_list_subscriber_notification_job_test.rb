# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WatchListSubscriberNotificationJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'notifies every subscribed user except the acting one' do
      subscriber = Object.new
      subscriber.define_singleton_method(:id) { 'user-2' }
      subscriber.define_singleton_method(:notification_frequency) { 'day' }

      users_relation = Object.new
      users_relation.define_singleton_method(:find_each) { |&block| block.call(subscriber) }

      except_relation = Object.new
      except_relation.define_singleton_method(:users) { users_relation }

      subscriptions = Object.new
      subscriptions.define_singleton_method(:except_user_id) { |_id| except_relation }

      watch_list = Object.new
      watch_list.define_singleton_method(:id) { 'wl-1' }
      watch_list.define_singleton_method(:subscriptions) { subscriptions }

      current_user = Object.new
      current_user.define_singleton_method(:id) { 'user-1' }

      delivered = []
      mail = Object.new
      mail.define_singleton_method(:deliver_later) { |wait_until:| delivered << wait_until }

      DataCycleCore::WatchListSubscriberNotificationJob.stub(:find_by_identifiers, nil) do
        DataCycleCore::SubscriptionMailer.stub(:notify_changed_watch_list_items, lambda { |user, changed_items|
          assert_equal subscriber, user
          assert_equal [{ type: 'add', id: 'c1', user_id: 'user-1' }], changed_items['wl-1']
          mail
        }) do
          DataCycleCore::WatchListSubscriberNotificationJob.perform_now(watch_list, current_user, ['c1'], 'add')
        end
      end

      assert_equal 1, delivered.size
    end
  end
end

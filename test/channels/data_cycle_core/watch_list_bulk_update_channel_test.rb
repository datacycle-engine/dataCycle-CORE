# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WatchListBulkUpdateChannelTest < ActionCable::Channel::TestCase
    tests DataCycleCore::WatchListBulkUpdateChannel
    include DataCycleCore::MinitestHookHelper

    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @watch_list = DataCycleCore::WatchList.create!(full_path: 'WatchListBulkUpdateChannel', user: @user)
    end

    test 'subscribes and streams when the user may bulk edit the watch list' do
      stub_connection current_user: @user
      subscribe watch_list_id: @watch_list.id

      assert_predicate subscription, :confirmed?
      assert_has_stream "bulk_update_#{@watch_list.id}_#{@user.id}"
    end

    test 'rejects when the watch list does not exist' do
      stub_connection current_user: @user
      subscribe watch_list_id: nil

      assert_predicate subscription, :rejected?
    end

    test 'rejects without a current_user' do
      stub_connection current_user: nil
      subscribe watch_list_id: @watch_list.id

      assert_predicate subscription, :rejected?
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WatchListBulkDeleteChannelTest < ActionCable::Channel::TestCase
    tests DataCycleCore::WatchListBulkDeleteChannel
    include DataCycleCore::MinitestHookHelper

    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @watch_list = DataCycleCore::WatchList.create!(full_path: 'WatchListBulkDeleteChannel', user: @user)
    end

    test 'subscribes and streams when the user may bulk delete the watch list' do
      stub_connection current_user: @user
      subscribe watch_list_id: @watch_list.id

      assert_predicate subscription, :confirmed?
      assert_has_stream "bulk_delete_#{@watch_list.id}"
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

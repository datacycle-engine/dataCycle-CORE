# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentLockChannelTest < ActionCable::Channel::TestCase
    tests DataCycleCore::ContentLockChannel
    include DataCycleCore::MinitestHookHelper

    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'ContentLockChannelArticle' })
    end

    test 'subscribes and streams when the feature is enabled and the content is visible' do
      DataCycleCore::Feature::ContentLock.stub(:enabled?, true) do
        stub_connection current_user: User.find_by(email: 'admin@datacycle.at')
        subscribe content_id: @content.id

        assert_predicate subscription, :confirmed?
        assert_has_stream "content_lock_#{@content.id}"
      end
    end

    test 'rejects when the feature is disabled' do
      DataCycleCore::Feature::ContentLock.stub(:enabled?, false) do
        stub_connection current_user: User.find_by(email: 'admin@datacycle.at')
        subscribe content_id: @content.id

        assert_predicate subscription, :rejected?
      end
    end

    test 'rejects when the content does not exist' do
      DataCycleCore::Feature::ContentLock.stub(:enabled?, true) do
        stub_connection current_user: User.find_by(email: 'admin@datacycle.at')
        subscribe content_id: nil

        assert_predicate subscription, :rejected?
      end
    end

    test 'rejects when there is no current_user' do
      DataCycleCore::Feature::ContentLock.stub(:enabled?, true) do
        stub_connection current_user: nil
        subscribe content_id: @content.id

        assert_predicate subscription, :rejected?
      end
    end
  end
end

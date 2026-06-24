# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationUpdateChannelTest < ActionCable::Channel::TestCase
    tests DataCycleCore::ClassificationUpdateChannel

    test 'subscribes and streams for a user that may index classification tree labels' do
      stub_connection current_user: User.find_by(email: 'admin@datacycle.at')

      subscribe

      assert_predicate subscription, :confirmed?
      assert_has_stream 'classification_update'
    end

    test 'rejects the subscription without a current_user' do
      stub_connection current_user: nil

      subscribe

      assert_predicate subscription, :rejected?
    end
  end
end

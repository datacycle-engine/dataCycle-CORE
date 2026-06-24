# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class BulkCreateChannelTest < ActionCable::Channel::TestCase
    tests DataCycleCore::BulkCreateChannel

    test 'subscribes and streams when the user may create assets' do
      user = User.find_by(email: 'admin@datacycle.at')
      stub_connection current_user: user
      subscribe overlay_id: 'overlay-1'

      assert_predicate subscription, :confirmed?
      assert_has_stream "bulk_create_overlay-1_#{user.id}"
    end

    test 'rejects without a current_user' do
      stub_connection current_user: nil
      subscribe overlay_id: 'overlay-1'

      assert_predicate subscription, :rejected?
    end
  end
end

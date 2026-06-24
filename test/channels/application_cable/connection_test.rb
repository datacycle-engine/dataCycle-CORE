# frozen_string_literal: true

require 'test_helper'

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    tests ApplicationCable::Connection

    WardenStub = Struct.new(:user)

    test 'connects with the verified warden user' do
      user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')

      connect env: { 'warden' => WardenStub.new(user) }

      assert_equal user, connection.current_user
    end

    test 'rejects the connection when no warden user is present' do
      assert_reject_connection { connect env: { 'warden' => WardenStub.new(nil) } }
    end

    test 'rejects the connection when warden is missing' do
      assert_reject_connection { connect }
    end
  end
end

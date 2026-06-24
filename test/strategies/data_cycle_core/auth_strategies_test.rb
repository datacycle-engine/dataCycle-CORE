# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AuthStrategiesTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'download token strategy does not store the user in the session' do
      strategy = DataCycleCore::DownloadTokenStrategy.new({})

      assert_not strategy.store?
    end

    test 'download token strategy fails for an unknown token' do
      strategy = DataCycleCore::DownloadTokenStrategy.new({})
      strategy.define_singleton_method(:params) { { download_token: 'token' } }

      DataCycleCore::Download.stub(:remove_token, nil) do
        DataCycleCore::User.stub(:find_by, nil) do
          strategy.authenticate!
        end
      end

      assert_equal 'invalid download token', strategy.message
    end

    test 'guest user strategy returns early when the user is missing' do
      strategy = DataCycleCore::GuestUserStrategy.new({})
      strategy.define_singleton_method(:session) { { guest_user_id: 'guest-1' } }

      DataCycleCore::User.stub(:find_by, nil) do
        assert_nil strategy.authenticate!
      end
    end

    test 'guest user strategy fails for an invalid guest user' do
      user = Object.new
      user.define_singleton_method(:valid_for_authentication?) { |&_block| false }
      user.define_singleton_method(:unauthenticated_message) { :invalid }

      strategy = DataCycleCore::GuestUserStrategy.new({})
      strategy.define_singleton_method(:session) { { guest_user_id: 'guest-1' } }

      DataCycleCore::User.stub(:find_by, user) do
        strategy.authenticate!
      end

      assert_equal 'invalid guest user', strategy.message
    end
  end
end

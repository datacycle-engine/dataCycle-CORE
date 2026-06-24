# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class RackAttackAuthThrottleTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @routes = Engine.routes
    end

    test 'rack-attack blocks excessive requests by user to API auth endpoint' do
      user = DataCycleCore::User.first
      ip = '1.2.3.4'

      # freeze time, so all requests fall into the same throttle window
      freeze_time do
        6.times do |i|
          post api_v4_authentication_login_path, params: { email: user.email, password: "wrong_extra#{i}", warden_strategy: 'email_password' }, headers: { 'REMOTE_ADDR' => ip }
          break if response.status.to_s == '429'
        end

        assert_response :too_many_requests
        assert_equal '429', response.status.to_s
        assert_predicate response.headers['Retry-After'], :present?
      end
    end

    test 'rack-attack blocks excessive requests by user to web auth endpoint' do
      user = DataCycleCore::User.first
      ip = '5.6.7.8'

      # freeze time, so all requests fall into the same throttle window
      freeze_time do
        6.times do |i|
          post '/users/sign_in', params: { user: { email: user.email, password: "wrong_extra#{i}" } }, headers: { 'REMOTE_ADDR' => ip }
          break if response.status.to_s == '429'
        end

        assert_response :too_many_requests
        assert_equal '429', response.status.to_s
        assert_predicate response.headers['Retry-After'], :present?
      end
    end

    test 'rack-attack blocks excessive requests by IP across multiple users to API auth endpoint' do
      users = DataCycleCore::User.limit(2).to_a
      raise 'need at least 2 users for this test' unless users.size == 2

      ip = '8.8.8.8'

      # freeze time, so all requests fall into the same throttle window
      freeze_time do
        11.times do |i|
          user = users[i % 2]
          post api_v4_authentication_login_path, params: { email: user.email, password: "wrong_extra#{i}", warden_strategy: 'email_password' }, headers: { 'REMOTE_ADDR' => ip }
          break if response.status.to_s == '429'
        end

        assert_response :too_many_requests
        assert_equal '429', response.status.to_s
        assert_predicate response.headers['Retry-After'], :present?
      end
    end

    test 'rack-attack blocks excessive requests by IP across multiple users to web auth endpoint' do
      users = DataCycleCore::User.limit(2).to_a
      raise 'need at least 2 users for this test' unless users.size == 2

      ip = '9.9.9.9'

      # freeze time, so all requests fall into the same throttle window
      freeze_time do
        11.times do |i|
          user = users[i % 2]
          post '/users/sign_in', params: { user: { email: user.email, password: "wrong_extra#{i}" } }, headers: { 'REMOTE_ADDR' => ip }
          break if response.status.to_s == '429'
        end

        assert_response :too_many_requests
        assert_equal '429', response.status.to_s
        assert_predicate response.headers['Retry-After'], :present?
      end
    end
  end
end

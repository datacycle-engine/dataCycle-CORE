# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AuthLockoutTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    include ActiveSupport::Testing::TimeHelpers

    before(:all) do
      @routes = Engine.routes

      @user_data = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
        email: "lock_test_#{Time.now.getutc.to_i}@datacycle.at",
        confirmed_at: 1.day.ago
      })

      @user = DataCycleCore::User.create(@user_data)
    end

    test '/api/v4/auth/login - failed attempts return 401' do
      3.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }

        assert_response :unauthorized
        assert_equal 401, response.status
      end
    end

    test '/users/sign_in - failed attempts return invalid, last_attempt and locked alerts' do
      1.times do |i| # rubocop:disable Lint/UselessTimes
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }

        assert_equal I18n.t('devise.failure.invalid', locale: DataCycleCore.ui_locales.first), flash[:alert]
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: 'wrong' } }

      assert_equal I18n.t('devise.failure.last_attempt', locale: DataCycleCore.ui_locales.first), flash[:alert]

      post '/users/sign_in', params: { user: { email: @user.email, password: 'wrong' } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]
    end

    test '/api/v4/auth/login - account is not locked under threshold' do
      2.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

      assert_response :success
      assert_equal 200, response.status
    end

    test '/users/sign_in - account is not locked under threshold' do
      2.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.sessions.signed_in', locale: DataCycleCore.ui_locales.first), flash[:notice]
    end

    test '/api/v4/auth/login - account is locked after threshold' do
      3.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

      assert_response :unauthorized
      assert_equal 401, response.status
    end

    test '/users/sign_in - account is locked after threshold' do
      3.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]
    end

    test '/api/v4/auth/login - API lockout is shared with browser sign-in (cross-flow blocking)' do
      3.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]
    end

    test '/users/sign_in - browser sign-in lockout is shared with API (cross-flow blocking)' do
      3.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: 'wrong', warden_strategy: 'email_password' }

      assert_response :unauthorized
      assert_equal 401, response.status
    end

    test '/api/v4/auth/login - account unlocks after 1 hour' do
      3.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

      assert_response :unauthorized
      assert_equal 401, response.status

      travel 1.hour + 1.second do
        post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

        assert_response :success
        assert_equal 200, response.status
      end
    end

    test '/users/sign_in - account unlocks after 1 hour' do
      3.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]

      travel 1.hour + 1.second do
        post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

        assert_equal I18n.t('devise.sessions.signed_in', locale: DataCycleCore.ui_locales.first), flash[:notice]
      end
    end

    test '/api/v4/auth/login - API unlocking is shared with browser sign-in (cross-flow blocking)' do
      3.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

      assert_response :unauthorized
      assert_equal 401, response.status

      travel 1.hour + 1.second do
        post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

        assert_equal I18n.t('devise.sessions.signed_in', locale: DataCycleCore.ui_locales.first), flash[:notice]
      end
    end

    test '/users/sign_in - browser sign-in unlocking is shared with API (cross-flow blocking)' do
      3.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]

      travel 1.hour + 1.second do
        post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

        assert_response :success
        assert_equal 200, response.status
      end
    end
  end
end

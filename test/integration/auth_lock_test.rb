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

    # walking one attempt past the lock hits the per email throttle, whose limit equals
    # Devise.maximum_attempts - throttling has its own coverage in rack_attack_auth_throttle_test
    setup do
      @rack_attack_enabled = Rack::Attack.enabled
      Rack::Attack.enabled = false
    end

    teardown { Rack::Attack.enabled = @rack_attack_enabled }

    test '/users/sign_in - automatic lock does not set locked_by' do
      Devise.maximum_attempts.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      @user.reload

      assert_nil @user.locked_by_id
      assert_predicate @user, :auto_locked?
      assert_predicate @user, :automatically_locked?
      assert_predicate @user, :access_locked?
    end

    test '/users/sign_in - lock set by another user does not expire' do
      locking_user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @user.lock_access!(locked_by: locking_user)

      assert_equal locking_user, @user.reload.locked_by

      travel Devise.unlock_in + 1.second do
        post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

        assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]
      end
    end

    # a lock without an actor (dc:privacy:lock_users_without_consent, soft delete) must not turn
    # into an expiring automatic lock: attempts are not counted against it, and the kind of lock
    # is persisted rather than read off failed_attempts
    test '/users/sign_in - system lock cannot be waited out by failing sign in' do
      user_data = @user_data.merge(email: "system_lock_#{Time.now.getutc.to_i}@datacycle.at")
      user = DataCycleCore::User.create(user_data)
      user.lock_access!
      user.update_columns(locked_at: 5.days.ago)

      Devise.maximum_attempts.times do |i|
        post '/users/sign_in', params: { user: { email: user.email, password: "wrong#{i}" } }
      end

      user.reload

      assert_equal 0, user.failed_attempts
      assert_operator user.locked_at, :<, Devise.unlock_in.ago
      assert_predicate user, :access_locked?

      travel Devise.unlock_in + 1.second do
        post '/users/sign_in', params: { user: { email: user.email, password: user_data[:password] } }

        assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]
        assert_predicate user.reload, :access_locked?
      end
    end

    # a user whose automatic lock has expired keeps failed_attempts at maximum_attempts - only a
    # successful sign in or an unlock resets it. dc:privacy:lock_users_without_consent picks those
    # users up (not_effectively_locked) and locks them without an actor, and that lock has to be
    # permanent instead of degrading into another hour long one
    test '/users/sign_in - system lock on top of an expired automatic lock cannot be waited out' do
      user_data = @user_data.merge(email: "expired_auto_#{Time.now.getutc.to_i}@datacycle.at")
      user = DataCycleCore::User.create(user_data)

      Devise.maximum_attempts.times do |i|
        post '/users/sign_in', params: { user: { email: user.email, password: "wrong#{i}" } }
      end

      user.reload

      assert_predicate user, :automatically_locked?

      user.update_columns(locked_at: Devise.unlock_in.ago - 1.second)
      user.reload

      assert_not user.access_locked?
      assert_equal Devise.maximum_attempts, user.failed_attempts
      assert_includes DataCycleCore::User.not_effectively_locked, user

      user.lock_access! # dc:privacy:lock_users_without_consent
      user.update_columns(locked_at: Devise.unlock_in.ago - 1.second)
      user.reload

      assert_not user.automatically_locked?
      assert_predicate user, :access_locked?

      post '/users/sign_in', params: { user: { email: user.email, password: user_data[:password] } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]
      assert_predicate user.reload, :access_locked?
    end

    test '/api/v4/auth/login - failed attempts return 401' do
      Devise.maximum_attempts.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }

        assert_response :unauthorized
        assert_equal 401, response.status
      end

      # one of only two paths allowed to mark a lock automatic
      assert_predicate @user.reload, :auto_locked?
    end

    test '/users/sign_in - failed attempts return invalid, last_attempt and locked alerts' do
      (Devise.maximum_attempts - 2).times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }

        assert_equal I18n.t('devise.failure.invalid', locale: DataCycleCore.ui_locales.first), flash[:alert]
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: 'wrong' } }

      assert_equal I18n.t('devise.failure.last_attempt', locale: DataCycleCore.ui_locales.first), flash[:alert]

      post '/users/sign_in', params: { user: { email: @user.email, password: 'wrong' } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]
    end

    test '/api/v4/auth/login - account is not locked under threshold' do
      (Devise.maximum_attempts - 1).times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

      assert_response :success
      assert_equal 200, response.status
    end

    test '/users/sign_in - account is not locked under threshold' do
      (Devise.maximum_attempts - 1).times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.sessions.signed_in', locale: DataCycleCore.ui_locales.first), flash[:notice]
    end

    test '/api/v4/auth/login - account is locked after threshold' do
      Devise.maximum_attempts.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

      assert_response :unauthorized
      assert_equal 401, response.status
    end

    # the two strings are asserted verbatim on purpose: API clients match on them, so changing
    # either constant has to break this test instead of travelling along with it
    test '/api/v4/auth/login - lockout is reported apart from invalid credentials' do
      (Devise.maximum_attempts - 1).times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }

        assert_equal 'invalid combination of email and password', response.parsed_body.dig('errors', 0, 'detail')
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: 'wrong', warden_strategy: 'email_password' }

      assert_predicate @user.reload, :access_locked?
      assert_equal 'account_locked', response.parsed_body.dig('errors', 0, 'detail')

      # the correct password while the lock is in effect must not read as a wrong one either
      post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

      assert_response :unauthorized
      assert_equal 'account_locked', response.parsed_body.dig('errors', 0, 'detail')
    end

    test '/users/sign_in - account is locked after threshold' do
      Devise.maximum_attempts.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]
    end

    test '/api/v4/auth/login - API lockout is shared with browser sign-in (cross-flow blocking)' do
      Devise.maximum_attempts.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]
    end

    test '/users/sign_in - browser sign-in lockout is shared with API (cross-flow blocking)' do
      Devise.maximum_attempts.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: 'wrong', warden_strategy: 'email_password' }

      assert_response :unauthorized
      assert_equal 401, response.status
    end

    test '/api/v4/auth/login - account unlocks after 1 hour' do
      Devise.maximum_attempts.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

      assert_response :unauthorized
      assert_equal 401, response.status

      travel Devise.unlock_in + 1.second do
        post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

        assert_response :success
        assert_equal 200, response.status
      end
    end

    test '/users/sign_in - account unlocks after 1 hour' do
      Devise.maximum_attempts.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]

      travel Devise.unlock_in + 1.second do
        post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

        assert_equal I18n.t('devise.sessions.signed_in', locale: DataCycleCore.ui_locales.first), flash[:notice]
      end
    end

    test '/api/v4/auth/login - API unlocking is shared with browser sign-in (cross-flow blocking)' do
      Devise.maximum_attempts.times do |i|
        post api_v4_authentication_login_path, params: { email: @user.email, password: "wrong#{i}", warden_strategy: 'email_password' }
      end

      post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

      assert_response :unauthorized
      assert_equal 401, response.status

      travel Devise.unlock_in + 1.second do
        post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

        assert_equal I18n.t('devise.sessions.signed_in', locale: DataCycleCore.ui_locales.first), flash[:notice]
      end
    end

    test '/users/sign_in - browser sign-in unlocking is shared with API (cross-flow blocking)' do
      Devise.maximum_attempts.times do |i|
        post '/users/sign_in', params: { user: { email: @user.email, password: "wrong#{i}" } }
      end

      post '/users/sign_in', params: { user: { email: @user.email, password: @user_data[:password] } }

      assert_equal I18n.t('devise.failure.locked', locale: DataCycleCore.ui_locales.first), flash[:alert]

      travel Devise.unlock_in + 1.second do
        post api_v4_authentication_login_path, params: { email: @user.email, password: @user_data[:password], warden_strategy: 'email_password' }

        assert_response :success
        assert_equal 200, response.status
      end
    end
  end
end

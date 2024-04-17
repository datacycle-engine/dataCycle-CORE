# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UsersTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @current_user = User.find_by(email: 'tester@datacycle.at')
      sign_in(@current_user)
    end

    test 'user does not exist' do
      logout

      post user_session_path, params: {
        user: {
          email: 'nonexistant@mail.com',
          password: 'nonexistant'
        }
      }, headers: {
        referer: user_session_path
      }

      assert_response :success
      assert_equal I18n.t('devise.failure.invalid', locale: DataCycleCore.ui_locales.first), flash[:alert]
    end

    test 'user settings page' do
      get settings_path
      assert_response :success
    end

    test 'show and filter users index page' do
      @test_group_ids = DataCycleCore::UserGroup.where(name: 'TestUserGroup').ids
      @guest = DataCycleCore::User.find_by(email: 'guest@datacycle.at')
      @guest.update(user_group_ids: @test_group_ids)

      get users_path, params: {
        q: 'guest datacycle',
        roles: DataCycleCore::Role.where(name: 'guest').ids,
        user_groups: @test_group_ids
      }
      assert_response :success
      assert_select 'li.grid-item .inner .description', { count: 1, text: 'guest@datacycle.at' }
    end

    test 'create new user' do
      user = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
        email: "tester_#{Time.now.getutc.to_i}@datacycle.at",
        role_id: DataCycleCore::Role.find_by(rank: 5)&.id,
        confirmed_at: Time.zone.now - 1.day
      })

      post create_user_users_path, params: {
        user:
      }, headers: {
        referer: users_path
      }

      assert_redirected_to users_path
      assert_equal I18n.t(:created, scope: [:controllers, :success], data: 'Benutzer', locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!
      assert_select 'li.grid-item .inner .description', user[:email]
      created_user = DataCycleCore::User.find_by(email: user[:email])
      assert_equal @current_user.id, created_user.creator.id
      assert_equal [created_user.id], @current_user.created_users.ids
    end

    test 'update existing user' do
      user = User.find_by(email: 'guest@datacycle.at')
      patch user_path(user), params: {
        user: {
          given_name: 'Guest1',
          access_token: '1',
          default_locale: 'en',
          notification_frequency: 'week'
        }
      }, headers: {
        referer: edit_user_path(user)
      }

      assert_redirected_to users_path
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: 'Benutzer', locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!
      assert_select 'li.grid-item > .inner > .title', "Guest1 #{user.family_name}"
      assert_select 'li.grid-item > .inner > .token', { count: 1, text: /.+/ }
      user.reload
      assert_equal user.notification_frequency, 'week'
      assert_equal user.default_locale, 'en'
    end

    test 'lock and unlock existing user' do
      user = User.find_by(email: 'guest@datacycle.at')

      delete lock_user_path(user), params: {}, headers: {
        referer: users_path
      }

      assert_redirected_to users_path
      assert_equal I18n.t(:locked, scope: [:controllers, :success], data: 'Benutzer', locale: DataCycleCore.ui_locales.first), flash[:notice]

      post unlock_user_path(user), params: {}, headers: {
        referer: users_path
      }

      assert_redirected_to users_path
      assert_equal I18n.t(:unlocked, scope: [:controllers, :success], data: 'Benutzer', locale: DataCycleCore.ui_locales.first), flash[:notice]
    end

    test 'search user by email' do
      user = User.find_by(email: 'admin@datacycle.at')
      get search_users_path, xhr: true, params: {
        q: 'admin'
      }

      assert_response :success
      users = JSON.parse(@response.body)

      assert_equal user.to_select_option.name, users.first['name']
    end

    test 'become specific user' do
      sign_in(User.find_by(email: 'admin@datacycle.at'))

      get user_become_path(User.find_by(email: 'guest@datacycle.at')), params: {}, headers: {
        referer: users_path
      }

      assert_redirected_to unauthorized_exception_path
      follow_redirect!
      assert_select 'button.show-sidebar > span', 'guest@datacycle.at'
    end
  end
end

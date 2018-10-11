# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserActionsTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'user does not exist' do
      logout

      post user_session_path, params: {
        user: User.find_by(email: 'guest@datacycle.at')&.to_json
      }

      assert_response :success
      assert_equal 'Ungültige Anmeldedaten.', flash[:alert]
    end

    test 'change user settings' do
      get settings_path
      assert_response :success
    end

    test 'show users index page' do
      get users_path
      assert_response :success
    end

    test 'create new user' do
      user = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').merge({
        email: "tester_#{Time.now.getutc.to_i}@datacycle.at",
        role_id: DataCycleCore::Role.find_by(rank: 5)&.id
      })

      post create_user_users_path, params: {
        user: user
      }, headers: {
        referer: users_path
      }

      assert_redirected_to users_path
      assert_equal 'Benutzer wurde erfolgreich erstellt.', flash[:success]
      follow_redirect!
      assert_select 'li.grid-item .inner .description', user[:email]
    end

    test 'update existing user' do
      user = DataCycleCore::User.find_by(email: 'guest@datacycle.at')

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
      assert_equal 'Benutzer wurde aktualisiert.', flash[:success]
      follow_redirect!
      assert_select 'li.grid-item > .inner > .title', "Guest1 #{user.family_name}"
      assert_select 'li.grid-item > .inner > .token', { count: 1, text: /.+/ }
      user.reload
      assert_equal user.notification_frequency, 'week'
      assert_equal user.default_locale, 'en'
    end

    test 'lock and unlock existing user' do
      user = DataCycleCore::User.find_by(email: 'guest@datacycle.at')

      delete user_path(user), params: {}, headers: {
        referer: users_path
      }

      assert_redirected_to users_path
      assert_equal 'Benutzer wurde gesperrt.', flash[:notice]

      post unlock_user_path(user), params: {}, headers: {
        referer: users_path
      }

      assert_redirected_to users_path
      assert_equal 'Benutzer wurde freigegeben.', flash[:notice]
    end

    test 'search user by email' do
      get search_users_path, xhr: true, params: {
        q: 'admin'
      }

      assert_response :success
      users = JSON.parse(@response.body)
      assert_equal users.first['email'], 'admin@datacycle.at'
    end

    test 'become specific user' do
      sign_in(User.find_by(email: 'admin@datacycle.at'))

      user = User.find_by(email: 'guest@datacycle.at')

      get user_become_path(user), params: {}, headers: {
        referer: users_path
      }

      assert_redirected_to info_path
      follow_redirect!
      assert_select 'button.show-sidebar > span', 'guest@datacycle.at'
    end
  end
end

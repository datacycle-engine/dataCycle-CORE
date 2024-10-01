# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserGroupsTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'show user_groups index page' do
      get user_groups_path, params: {
        q: 'test group'
      }
      assert_response :success
      assert_select 'li.grid-item > .inner > .title', { count: 1, text: 'TestUserGroup' }
    end

    test 'create new user_group' do
      group_name = "test_group_#{Time.now.getutc.to_i}"
      post create_user_groups_path, params: {
        user_group: {
          name: group_name
        }
      }, headers: {
        referer: user_groups_path
      }

      assert_redirected_to user_groups_path
      assert_equal I18n.t(:created, scope: [:controllers, :success], data: 'Benutzergruppe', locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!
      assert_select 'li.grid-item > .inner > .title', group_name
    end

    test 'update existing user_group' do
      group_name = "test_group_#{Time.now.getutc.to_i}"
      user_group = DataCycleCore::UserGroup.find_by(name: 'TestUserGroup')
      user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')

      patch user_group_path(user_group), params: {
        user_group: {
          name: group_name,
          user_ids: [
            user&.id
          ]
        }
      }, headers: {
        referer: edit_user_group_path(user_group)
      }

      assert_redirected_to user_groups_path
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: 'Benutzergruppe', locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!
      assert_select 'li.grid-item > .inner > .infoRow > .title', 'Benutzergruppe (1)'
      assert_select 'li.grid-item > .inner > .title', group_name
    end

    test 'delete user_group' do
      user_group = DataCycleCore::UserGroup.find_by(name: 'TestUserGroup')

      delete user_group_path(user_group), params: {}, headers: {
        referer: user_groups_path
      }

      assert_redirected_to user_groups_path
      assert_equal I18n.t(:destroyed, scope: [:controllers, :success], data: 'Benutzergruppe', locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!
      assert_select 'li.grid-item > .inner > .title', { count: 0, text: 'TestUserGroup' }
    end
  end
end

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

    test 'user_group permissions' do
      test_collection = DataCycleCore::WatchList.create(full_path: 'user_group testsammlung')
      @dummy_poi = DataCycleCore::Thing.create(template_name: 'POI', name: 'test poi')
      test_collection.add_things_from_query(DataCycleCore::Thing.where(id: @dummy_poi.id))

      role_id = DataCycleCore::Role.find_by(name: 'standard').id

      group_name = "permissions_test_group_#{Time.now.getutc.to_i}"

      user = DataCycleCore::User.create!(
        given_name: 'Test',
        family_name: 'TEST',
        email: "#{SecureRandom.base64(12)}@pixelpoint.at",
        password: 'password',
        role_id:
      )

      user_group = DataCycleCore::UserGroup.create(name: group_name)

      patch user_group_path(user_group), params: { user_group: {
        name: group_name,
        user_ids: [
          user&.id
        ],
        permissions: ['test_permission'],
        shared_collection_ids: [test_collection.id]
      } }, headers: {
        referer: edit_user_group_path(user_group)
      }

      assert_equal true, user.cannot?(:merge_duplicates, @dummy_poi)
      assert_equal true, user.can?(:view_life_cycle, @dummy_poi)
    end
  end
end

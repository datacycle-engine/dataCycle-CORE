# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserGroupsTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'tester@datacycle.at'))

      role_id = DataCycleCore::Role.find_by(name: 'guest').id

      DataCycleCore::User.create!(
        given_name: 'Test',
        family_name: 'TEST',
        email: 'user_group_tester_guest@pixelpoint.at',
        password: 'password',
        role_id:
      )
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

    test 'user_group permissions, with collection, no template' do
      test_collection = DataCycleCore::WatchList.create(full_path: 'user_group testsammlung')
      @dummy_poi = DataCycleCore::Thing.create(template_name: 'POI', name: 'test poi')
      test_collection.add_things_from_query(DataCycleCore::Thing.where(id: @dummy_poi.id))

      user = DataCycleCore::User.find_by(email: 'user_group_tester_guest@pixelpoint.at')

      permission_user_group_create([user&.id], ['test_permission_1'], [test_collection.id])

      assert_equal false, user.can?(:merge_duplicates, @dummy_poi)
      assert_equal true, user.can?(:view_life_cycle, @dummy_poi)
    end

    test 'user_group permissions, with collection, with template' do
      test_collection = DataCycleCore::WatchList.create(full_path: 'user_group testsammlung')
      @dummy_poi = DataCycleCore::Thing.create(template_name: 'POI', name: 'test poi')
      @dummy_img = DataCycleCore::Thing.create(template_name: 'Bild', name: 'test img')
      test_collection.add_things_from_query(DataCycleCore::Thing.where(id: [@dummy_poi.id, @dummy_img.id]))

      user = DataCycleCore::User.find_by(email: 'user_group_tester_guest@pixelpoint.at')

      permission_user_group_create([user&.id], ['test_permission_2'], [test_collection.id])

      assert_equal false, user.can?(:merge_duplicates, @dummy_poi)
      assert_equal true, user.can?(:view_life_cycle, @dummy_poi)
      assert_equal false, user.can?(:view_life_cycle, @dummy_img)
    end

    test 'user_group permissions, no collection, with template' do
      test_collection = DataCycleCore::WatchList.create(full_path: 'user_group testsammlung')
      @dummy_poi = DataCycleCore::Thing.create(template_name: 'POI', name: 'test poi')
      @dummy_poi2 = DataCycleCore::Thing.create(template_name: 'POI', name: 'test poi 2')
      @dummy_img = DataCycleCore::Thing.create(template_name: 'Bild', name: 'test img')

      test_collection.add_things_from_query(DataCycleCore::Thing.where(id: [@dummy_poi.id, @dummy_img.id]))

      user = DataCycleCore::User.find_by(email: 'user_group_tester_guest@pixelpoint.at')

      permission_user_group_create([user&.id], ['test_permission_3'], [])

      assert_equal false, user.can?(:merge_duplicates, @dummy_poi)
      assert_equal true, user.can?(:view_life_cycle, @dummy_poi)
      assert_equal true, user.can?(:view_life_cycle, @dummy_poi2)
      assert_equal false, user.can?(:view_life_cycle, @dummy_img)
    end

    private

    def permission_user_group_create(user_ids = [], permissions = [], collection_ids = [])
      post create_user_groups_path, params: {
        user_group: {
          name: "permissions_test_group_#{Time.now.getutc.to_i}",
          user_ids:,
          permissions:,
          shared_collection_ids: collection_ids
        }
      }, headers: {
        referer: user_groups_path
      }
    end
  end
end

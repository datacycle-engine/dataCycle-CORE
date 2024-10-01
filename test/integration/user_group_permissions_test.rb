# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserGroupPermissionsTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'tester@datacycle.at'))

      role_id = DataCycleCore::Role.find_by(name: 'guest').id

      @user = DataCycleCore::User.create!(
        given_name: 'Test',
        family_name: 'TEST',
        email: 'user_group_tester_guest@pixelpoint.at',
        password: 'password',
        role_id:
      )

      DataCycleCore.features[:user_group_permission][:enabled] = true

      @dummy_poi1 = DataCycleCore::Thing.create(template_name: 'POI', name: 'test poi 1')
      @dummy_poi2 = DataCycleCore::Thing.create(template_name: 'POI', name: 'test poi 2')
      @dummy_event = DataCycleCore::Thing.create(template_name: 'Event', name: 'test event')

      @test_collection1 = permission_group_base_watchlist_create([@dummy_poi1])
      @test_collection2 = permission_group_base_watchlist_create([@dummy_poi1, @dummy_event])

      @test_group1 = permission_user_group_create([], ['test_permission_1'], [@test_collection1.id])
      @test_group2 = permission_user_group_create([], ['test_permission_2'], [@test_collection2.id])
      @test_group3 = permission_user_group_create([], ['test_permission_3'])
    end

    teardown do
      @test_group1.destroy
      @test_group2.destroy
      @test_group3.destroy
      @test_collection1.destroy
      @test_collection2.destroy
      @dummy_poi1.destroy
      @dummy_poi2.destroy
      @dummy_event.destroy
      @user.destroy
    end

    test 'user_group permissions, with collection, no template' do
      reset_permission_test_user_groups

      @test_group1.user_ids = [@user.id]

      assert_not @user.can?(:merge_duplicates, @dummy_poi1)
      assert @user.can?(:set_life_cycle, @dummy_poi1)
    end

    test 'user_group permissions, with collection, with template' do
      reset_permission_test_user_groups

      @test_group2.user_ids = [@user.id]

      assert_not @user.can?(:merge_duplicates, @dummy_poi1)
      assert @user.can?(:set_life_cycle, @dummy_poi1)
      assert_not @user.can?(:set_life_cycle, @dummy_event)
    end

    test 'user_group permissions, no collection, with template' do
      reset_permission_test_user_groups

      @test_group3.user_ids = [@user.id]

      assert @user.can?(:set_life_cycle, @dummy_poi1)
      assert @user.can?(:set_life_cycle, @dummy_poi2)
      assert_not @user.can?(:set_life_cycle, @dummy_event)
    end

    private

    def permission_user_group_create(user_ids = [], permissions = [], collection_ids = [])
      name = "permissions_test_group_#{Time.now.getutc.to_i}_#{permissions.join('_')}"

      post create_user_groups_path, params: {
        user_group: {
          name:,
          user_ids:,
          permissions:,
          shared_collection_ids: collection_ids
        }
      }, headers: {
        referer: user_groups_path
      }
      DataCycleCore::UserGroup.find_by(name:)
    end

    def permission_group_base_watchlist_create(things = [])
      name = "permissions_test_group_#{Time.now.getutc.to_i}_#{Digest::MD5.hexdigest(things.pluck(:name).join('.'))}"

      post watch_lists_path, xhr: true, params: {
        watch_list: {
          full_path: name
        }
      }, headers: {
        referer: root_path
      }

      watch_list = DataCycleCore::WatchList.find_by(name:)

      things.each do |thing|
        next unless thing.is_a?(DataCycleCore::Thing)
        next if watch_list.blank?

        get add_item_watch_list_path(watch_list), xhr: true, params: {
          hashable_id: thing.id,
          hashable_type: thing.class.name
        }, headers: {
          referer: root_path
        }
      end

      DataCycleCore::WatchList.find_by(name:)
    end

    def reset_permission_test_user_groups
      @test_group1.user_ids = []
      @test_group2.user_ids = []
      @test_group3.user_ids = []
    end
  end
end

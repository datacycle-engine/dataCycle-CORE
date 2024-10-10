# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserGroupPermissionsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    before(:all) do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'tester@datacycle.at'))

      role_id = DataCycleCore::Role.find_by(name: 'guest').id

      @permissions_test_user = DataCycleCore::User.create!(
        given_name: 'Test',
        family_name: 'TEST',
        email: 'user_group_tester_guest@pixelpoint.at',
        password: 'password',
        role_id:
      )

      DataCycleCore.features[:user_group_permission][:enabled] = true
      DataCycleCore::Feature::UserGroupPermission.reload

      @dummy_poi1 = DataCycleCore::Thing.create!(template_name: 'POI', name: 'test poi 1')
      @dummy_event = DataCycleCore::Thing.create!(template_name: 'Event', name: 'test event')

      @test_collection1 = permission_group_base_watchlist_create([@dummy_poi1])
      @test_collection2 = permission_group_base_watchlist_create([@dummy_poi1, @dummy_event])

      @test_group1 = permission_user_group_create([], ['test_permission_1'], [@test_collection1.id])
      @test_group2 = permission_user_group_create([], ['test_permission_2'], [@test_collection2.id])
    end

    after(:all) do
      DataCycleCore.features[:user_group_permission][:enabled] = false
      DataCycleCore::Feature::UserGroupPermission.reload
    end

    test 'user_group permissions, with collection, set_life_cycle poi' do
      reset_permission_test_user_groups
      update_permissions_test_user_group(@test_group1, {user_ids: [@permissions_test_user.id]})

      assert @permissions_test_user.can?(:set_life_cycle, @dummy_poi1)
      assert @permissions_test_user.cannot?(:set_life_cycle, @dummy_event)
      assert @permissions_test_user.cannot?(:merge_duplicates, @dummy_poi1)
      assert @permissions_test_user.cannot?(:merge_duplicates, @dummy_event)
    end

    test 'user_group permissions, with collection, merge_duplicates' do
      reset_permission_test_user_groups
      update_permissions_test_user_group(@test_group2, {user_ids: [@permissions_test_user.id]})

      assert @permissions_test_user.can?(:merge_duplicates, @dummy_poi1)
      assert @permissions_test_user.can?(:merge_duplicates, @dummy_event)
      assert @permissions_test_user.cannot?(:set_life_cycle, @dummy_poi1)
      assert @permissions_test_user.cannot?(:set_life_cycle, @dummy_event)
    end

    private

    def permission_user_group_create(user_ids = [], permissions = [], collection_ids = [])
      name = "permissions_test_group_#{Time.now.getutc.to_i}_#{permissions.join('_')}"

      DataCycleCore::UserGroup.create!({
        name:,
        user_ids:,
        permissions:,
        shared_collection_ids: collection_ids
      })
    end

    def permission_group_base_watchlist_create(things = [])
      name = "permissions_test_group_#{Time.now.getutc.to_i}_#{Digest::MD5.hexdigest(things.pluck(:name).join('.'))}"

      DataCycleCore::WatchList.create!({
        full_path: name,
        thing_ids: things.map(&:id)
      })
    end

    def reset_permission_test_user_groups
      update_permissions_test_user_group(@test_group1, {user_ids: []})
      update_permissions_test_user_group(@test_group2, {user_ids: []})
    end

    def update_permissions_test_user_group(group, hash = {user_ids: []})
      group.update(hash)
    end
  end
end

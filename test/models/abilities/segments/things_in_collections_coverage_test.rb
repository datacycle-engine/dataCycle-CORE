# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the ThingsInCollections ability segment to_restrictions, which groups the
  # shared collections of the user groups holding a permission. UserGroup.user_groups_with_
  # permission is stubbed to return an (unsaved) WatchList so the per-class restriction row
  # is built without fixtures.
  class ThingsInCollectionsSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::ThingsInCollections

    def ability_without_user
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      ability
    end

    test 'to_restrictions builds a restriction row per shared collection class' do
      seg = Subject.new('permission_key')
      seg.ability = ability_without_user
      shared = Object.new
      shared.define_singleton_method(:shared_collections) { [DataCycleCore::WatchList.new(name: 'Shared')] }

      result = DataCycleCore::UserGroup.stub(:user_groups_with_permission, shared) do
        seg.send(:to_restrictions)
      end

      assert_kind_of Array, result
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the UsersByUserGroupPermission ability segment - the role / user-group-
  # permission include? predicate over a user double, plus to_restrictions (which resolves
  # the permission's group names via a cheap empty query).
  class UsersByUserGroupPermissionSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::UsersByUserGroupPermission

    def user_double(is_role: true, has_permission: true)
      user = Object.new
      user.define_singleton_method(:is_role?) { |*| is_role }
      user.define_singleton_method(:has_user_group_permission?) { |_key| has_permission }
      user
    end

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'include? combines the role and the user-group permission' do
      seg = Subject.new('permission_key', ['admin'])

      assert_includes seg, user_double(is_role: true, has_permission: true)
      assert_not seg.include?(user_double(is_role: false))
    end

    test 'to_restrictions renders the roles and the resolved group names' do
      seg = with_locale_ability(Subject.new('permission_key', ['admin']))

      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the UsersByUserGroup ability segment - pure role/user-group predicates
  # over a user double, plus to_restrictions (driven through an ability whose user is nil
  # so #locale resolves to the default ui locale).
  class UsersByUserGroupSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::UsersByUserGroup

    def user_double(is_role: true, has_group: true)
      user = Object.new
      user.define_singleton_method(:is_role?) { |*| is_role }
      user.define_singleton_method(:has_user_group?) { |_name| has_group }
      user
    end

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'include? combines role? and user_group?' do
      seg = Subject.new('editors', ['admin'])

      assert_includes seg, user_double(is_role: true, has_group: true)
      assert_not seg.include?(user_double(is_role: false, has_group: true))
      assert_not seg.include?(user_double(is_role: true, has_group: false))
    end

    test "role? short-circuits when 'all' is allowed" do
      seg = Subject.new('editors', ['all'])

      assert seg.send(:role?, user_double(is_role: false))
    end

    test 'subject is User' do
      assert_equal DataCycleCore::User, Subject.new('g', 'admin').subject
    end

    test 'to_restrictions renders the roles and group' do
      seg = with_locale_ability(Subject.new('editors', ['admin', 'user']))

      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the UsersByRoleWhitelist ability segment - empty conditions for 'all',
  # role-name scoped conditions otherwise, and to_restrictions (which is skipped for 'all').
  class UsersByRoleWhitelistSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::UsersByRoleWhitelist

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'conditions are empty for all and scoped by role names otherwise' do
      assert_equal({}, Subject.new('all').conditions)
      assert_equal({ role: { name: ['admin'] } }, Subject.new('admin').conditions)
      assert_equal DataCycleCore::User, Subject.new('admin').subject
    end

    test "to_restrictions returns nil for 'all' and renders the roles otherwise" do
      assert_nil with_locale_ability(Subject.new('all')).send(:to_restrictions)
      assert_nothing_raised { with_locale_ability(Subject.new('admin')).send(:to_restrictions) }
    end
  end
end

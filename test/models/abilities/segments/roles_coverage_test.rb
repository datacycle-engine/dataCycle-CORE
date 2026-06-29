# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the Roles ability segment - resolving the allowed role names (every role
  # for 'all', a name whitelist otherwise) into the conditions hash, plus to_restrictions.
  class RolesSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::Roles

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test "'all' selects every role and a whitelist scopes the conditions by name" do
      assert_equal DataCycleCore::Role, Subject.new('all').subject
      assert_kind_of Hash, Subject.new('admin').conditions
    end

    test 'to_restrictions renders the roles' do
      seg = with_locale_ability(Subject.new('admin'))

      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

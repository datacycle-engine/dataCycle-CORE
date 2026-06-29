# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the SubjectByUserRolesWhitelist ability segment - the conditions hash
  # scoping a subject by a user attribute's role whitelist, plus to_restrictions.
  class SubjectByUserRolesWhitelistSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::SubjectByUserRolesWhitelist

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'conditions scope the subject by the user attribute role whitelist' do
      seg = Subject.new(DataCycleCore::Thing, 'created_by', ['admin'])

      assert_equal({ created_by: { role: { name: ['admin'] } } }, seg.conditions)
      assert_equal DataCycleCore::Thing, seg.subject
    end

    test 'to_restrictions renders the whitelisted roles' do
      seg = with_locale_ability(Subject.new(DataCycleCore::Thing, 'created_by', ['admin']))

      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

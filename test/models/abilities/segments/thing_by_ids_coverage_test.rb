# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the ThingByIds ability segment - the id conditions hash and
  # to_restrictions.
  class ThingByIdsSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::ThingByIds

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'conditions scope things by id and to_restrictions renders the ids' do
      seg = with_locale_ability(Subject.new('id-1', 'id-2'))

      assert_equal({ id: ['id-1', 'id-2'] }, seg.conditions)
      assert_equal DataCycleCore::Thing, seg.subject
      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

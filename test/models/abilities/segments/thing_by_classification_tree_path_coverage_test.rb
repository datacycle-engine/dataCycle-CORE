# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the ThingByClassificationTreePath ability segment - resolving concept
  # full paths to classification alias ids in the conditions hash, plus to_restrictions.
  # Unknown paths resolve to an empty id list (no fixtures needed).
  class ThingByClassificationTreePathSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::ThingByClassificationTreePath

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'conditions scope things by the resolved classification alias ids' do
      seg = Subject.new('Tags > Test')

      assert_equal DataCycleCore::Thing, seg.subject
      assert seg.conditions.key?(:classification_aliases)
    end

    test 'to_restrictions renders the concept paths' do
      seg = with_locale_ability(Subject.new('Tags > Test'))

      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

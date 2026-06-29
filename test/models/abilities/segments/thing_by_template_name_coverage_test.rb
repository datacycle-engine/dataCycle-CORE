# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the ThingByTemplateName ability segment - the template-name conditions
  # hash and to_restrictions.
  class ThingByTemplateNameSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::ThingByTemplateName

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'conditions scope things by template name and to_restrictions renders them' do
      seg = with_locale_ability(Subject.new('Artikel', 'Veranstaltung'))

      assert_equal({ template_name: ['Artikel', 'Veranstaltung'] }, seg.conditions)
      assert_equal DataCycleCore::Thing, seg.subject
      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

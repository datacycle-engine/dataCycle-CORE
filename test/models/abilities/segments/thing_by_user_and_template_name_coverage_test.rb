# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the ThingByUserAndTemplateName ability segment - the conditions hash
  # (template names + the user attribute scoped to the current user) and to_restrictions,
  # over an ability whose user is nil so #locale resolves to the default ui locale.
  class ThingByUserAndTemplateNameSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::ThingByUserAndTemplateName

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'conditions scope by template names and the user attribute' do
      seg = with_locale_ability(Subject.new('created_by', 'Artikel', 'Veranstaltung'))

      conditions = seg.conditions

      assert_equal ['Artikel', 'Veranstaltung'], conditions[:template_name]
      assert_nil conditions[:created_by]
    end

    test 'subject is Thing and to_restrictions renders the attribute and template names' do
      seg = with_locale_ability(Subject.new('created_by', 'Artikel'))

      assert_equal DataCycleCore::Thing, seg.subject
      assert_nothing_raised { seg.send(:to_restrictions, subject: DataCycleCore::Thing) }
    end
  end
end

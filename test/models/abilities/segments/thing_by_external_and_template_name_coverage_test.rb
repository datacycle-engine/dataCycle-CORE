# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the ThingByExternalAndTemplateName ability segment - the include?
  # predicate (external thing whose template is listed), to_proc and to_restrictions.
  class ThingByExternalAndTemplateNameSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::ThingByExternalAndTemplateName

    def thing_double(external:, template_name: 'Artikel')
      thing = Object.new
      thing.define_singleton_method(:external?) { external }
      thing.define_singleton_method(:template_name) { template_name }
      thing
    end

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test 'include? requires an external thing whose template is listed' do
      seg = Subject.new(['Artikel'])

      assert_includes seg, thing_double(external: true, template_name: 'Artikel')
      assert_not seg.include?(thing_double(external: false, template_name: 'Artikel'))
      assert_not seg.include?(thing_double(external: true, template_name: 'Veranstaltung'))
    end

    test 'subject is Thing, to_proc delegates and to_restrictions renders template names' do
      seg = with_locale_ability(Subject.new(['Artikel']))

      assert_equal DataCycleCore::Thing, seg.subject
      assert seg.to_proc.call(thing_double(external: true, template_name: 'Artikel'))
      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

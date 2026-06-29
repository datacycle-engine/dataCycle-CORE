# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the TemplateByCreatableScopeAndTemplateName ability segment - the
  # 'all'-scope and explicit-scope include? branches (the template name must be listed)
  # plus to_restrictions, over a content double (ability user nil -> default ui locale).
  class TemplateByCreatableScopeAndTemplateNameSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::TemplateByCreatableScopeAndTemplateName

    def obj_double(template_name: 'Artikel', creatable: true)
      obj = Object.new
      obj.define_singleton_method(:template_name) { template_name }
      obj.define_singleton_method(:creatable?) { |_scope| creatable }
      obj
    end

    def with_locale_ability(seg)
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      seg.ability = ability
      seg
    end

    test "include? for the 'all' scope requires creatable? and a listed template name" do
      seg = Subject.new('all', ['Artikel'])

      assert seg.include?(obj_double(template_name: 'Artikel'), 'create') # rubocop:disable Minitest/AssertIncludes
      assert_not seg.include?(obj_double(template_name: 'Veranstaltung'), 'create')
    end

    test 'include? for an explicit scope requires the scope to be listed' do
      seg = Subject.new(['create'], ['Artikel'])

      assert seg.include?(obj_double(template_name: 'Artikel'), 'create') # rubocop:disable Minitest/AssertIncludes
      assert_not seg.include?(obj_double(template_name: 'Artikel'), 'update')
    end

    test 'subject is Thing and to_proc delegates to include?' do
      seg = Subject.new('all', ['Artikel'])

      assert_equal DataCycleCore::Thing, seg.subject
      assert seg.to_proc.call(obj_double, 'create')
    end

    test 'to_restrictions renders the scopes and template names' do
      seg = with_locale_ability(Subject.new(['create'], ['Artikel']))

      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

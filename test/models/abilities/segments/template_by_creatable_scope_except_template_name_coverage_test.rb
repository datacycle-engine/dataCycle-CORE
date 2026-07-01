# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the TemplateByCreatableScopeExceptTemplateName ability segment - the
  # 'all'-scope and explicit-scope include? branches over a content double, plus
  # to_restrictions (ability user nil -> default ui locale).
  class TemplateByCreatableScopeSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::TemplateByCreatableScopeExceptTemplateName

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

    test "include? for the 'all' scope checks creatable? and excludes listed template names" do
      seg = Subject.new('all', ['Veranstaltung'])

      assert seg.include?(obj_double(template_name: 'Artikel'), 'create') # rubocop:disable Minitest/AssertIncludes
      assert_not seg.include?(obj_double(template_name: 'Veranstaltung'), 'create')
      assert_not seg.include?(obj_double(creatable: false), 'create')
    end

    test 'include? for an explicit scope requires the scope to be listed' do
      seg = Subject.new(['create'], ['Veranstaltung'])

      assert seg.include?(obj_double(template_name: 'Artikel'), 'create') # rubocop:disable Minitest/AssertIncludes
      assert_not seg.include?(obj_double(template_name: 'Artikel'), 'update')
    end

    # Regression: CanCanCan calls the rule block with only the subject when the
    # authorize! scope (passed as the attribute) is nil, e.g. authorize!(:create, template, nil).
    # include? must tolerate a missing scope instead of raising ArgumentError.
    test 'include? tolerates a missing scope (single argument) and denies' do
      seg = Subject.new(['create'], ['Veranstaltung'])

      assert_nothing_raised { seg.include?(obj_double(template_name: 'Artikel')) }
      assert_not seg.include?(obj_double(template_name: 'Artikel'))
      assert_nothing_raised { seg.to_proc.call(obj_double(template_name: 'Artikel')) }
    end

    test 'subject is Thing and to_proc delegates to include?' do
      seg = Subject.new('all', [])

      assert_equal DataCycleCore::Thing, seg.subject
      assert seg.to_proc.call(obj_double, 'create')
    end

    test 'to_restrictions renders the scopes and template names' do
      seg = with_locale_ability(Subject.new(['create'], ['Veranstaltung']))

      assert_nothing_raised { seg.send(:to_restrictions) }
    end
  end
end

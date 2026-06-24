# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationHelperTest < ActionView::TestCase
    include DataCycleCore::ClassificationHelper
    include DataCycleCore::UiLocaleHelper

    ColorDouble = Struct.new(:has_color, :color) do
      def color? = has_color
    end

    ConceptDouble = Struct.new(:full_path, :description, :name_i18n) do
      def first_available_locale(_default = nil) = :de
    end

    test 'matched_concept_path wraps matches in mark tags' do
      assert_equal 'Hello World', matched_concept_path('Hello World', [])
      assert_equal '', matched_concept_path('', ['x'])
      assert_equal 'Hello <mark>World</mark>', matched_concept_path('Hello World', ['World'])
      assert_equal 'Hello', matched_concept_path('Hello', ['xyz'])
    end

    test 'classification_title reads the name, internal name or DELETED' do
      assert_equal 'DELETED', classification_title(Object.new)
      assert_equal 'Tag', classification_title(DataCycleCore::Classification.new(name: 'Tag'))
      assert_equal 'Alias', classification_title(DataCycleCore::ClassificationAlias.new(internal_name: 'Alias'))
    end

    test 'classification_style returns a css variable only when a color is set' do
      assert_nil classification_style(nil)
      assert_nil classification_style(ColorDouble.new(false, nil))
      assert_equal '--classification-color: #fff;', classification_style(ColorDouble.new(true, '#fff'))
    end

    test 'expected_classification_alias unwraps a Classification' do
      assert_equal 'x', expected_classification_alias('x')
      assert_nil expected_classification_alias(DataCycleCore::Classification.new)
    end

    test 'expected_value_id resolves the id for the expected type' do
      direct = struct_double(id: 'direct')

      assert_equal 'direct', expected_value_id(direct, direct.class)
      assert_equal 'pc-1', expected_value_id(struct_double(primary_classification: struct_double(id: 'pc-1')), DataCycleCore::Classification)
      assert_equal 'pca-1', expected_value_id(struct_double(primary_classification_alias: struct_double(id: 'pca-1')), DataCycleCore::ClassificationAlias)
    end

    test 'concept_scheme_visibility_icon maps the visibility to an icon' do
      assert_includes concept_scheme_visibility_icon('list'), 'fa-th-list'
      assert_includes concept_scheme_visibility_icon('tree_view'), 'fa-sitemap'
      assert_includes concept_scheme_visibility_icon('unknown'), 'fa-info-circle'
    end

    test 'async_classification_select_options is an empty select for a blank value' do
      assert_equal '', async_classification_select_options(nil)
    end

    test 'group_key_for_ctl uses the external source name when present' do
      assert_equal 'Feratel', group_key_for_ctl(struct_double(external_source_id: 5), { 5 => struct_double(name: 'Feratel') })
      assert_equal 5, group_key_for_ctl(struct_double(external_source_id: 5), {})
    end

    test 'classification_tooltip is nil for a nil concept' do
      assert_nil classification_tooltip(nil)
    end

    test 'classification_tooltip renders the full path' do
      assert_includes classification_tooltip(ConceptDouble.new('A > B', nil, {})), 'tag-full-path'
    end

    test 'classification_tooltip lists grouped translations' do
      html = classification_tooltip(ConceptDouble.new('A', nil, { 'de' => 'Name', 'en' => 'Name' }))

      assert_includes html, 'tag-translations'
    end

    test 'grouped_concept_scheme_visibilities returns one entry per visibility group' do
      result = grouped_concept_scheme_visibilities(struct_double(id: 'cs-1'))

      assert_kind_of Array, result
      assert result.first.key?(:key)
    end
  end
end

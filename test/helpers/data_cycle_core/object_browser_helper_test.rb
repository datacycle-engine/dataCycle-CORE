# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ObjectBrowserHelperTest < ActionView::TestCase
    include DataCycleCore::ObjectBrowserHelper
    include DataCycleCore::UiLocaleHelper

    def current_user = nil
    def cannot?(*_args) = @cannot_create
    def new_content_select_options(**_opts) = @creatable_templates

    # The "not" check in extract_aliases inspects the keys of the inner value
    # hash, while extract_classification_paths inspects the outer filter key.
    def definition_with_filters
      {
        'stored_filter' => [
          { 'a' => { 'withClassificationAliasesAndTreename' => 'x', 'value' => 'Inhaltstypen', 'aliases' => ['Article', 'POI'] } },
          { 'b' => { 'withNotClassificationAliasesAndTreename' => 'x', 'value' => 'Inhaltstypen', 'aliases' => ['Event'] } },
          { 'c' => { 'withClassificationAliasesAndTreename' => 'x', 'value' => 'SchemaTypes', 'aliases' => ['Place'] } },
          { 'with_classification_paths' => ['Inhaltstypen > Article', 'SchemaTypes > Place'] },
          { 'not_with_classification_paths' => ['Inhaltstypen > Event'] }
        ]
      }
    end

    test 'extract_aliases collects aliases for a value without a not key' do
      assert_equal ['Article', 'POI'], extract_aliases(definition_with_filters, 'Inhaltstypen')
    end

    test 'extract_aliases collects aliases for a value with a not key' do
      assert_equal ['Event'], extract_aliases(definition_with_filters, 'Inhaltstypen', with_not: true)
    end

    test 'extract_aliases returns nil for a blank definition' do
      assert_nil extract_aliases(nil, 'Inhaltstypen')
      assert_nil extract_aliases({}, 'Inhaltstypen')
    end

    test 'extract_classification_paths collects positive paths' do
      assert_equal ['Inhaltstypen > Article', 'SchemaTypes > Place'], extract_classification_paths(definition_with_filters)
    end

    test 'extract_classification_paths collects negated paths' do
      assert_equal ['Inhaltstypen > Event'], extract_classification_paths(definition_with_filters, with_not: true)
    end

    test 'extract_classification_paths returns nil for a blank definition' do
      assert_nil extract_classification_paths(nil)
    end

    test 'filter_definition builds the full set of query methods from the definition' do
      result = send(:filter_definition, definition_with_filters)
      by_method = result.index_by { |f| f[:method] }

      assert_equal ['Article', 'POI'], by_method['with_default_data_type'][:value]
      assert_equal ['Event'], by_method['without_default_data_type'][:value]
      assert_equal ['SchemaTypes > Place'], by_method['with_schema_classification_paths'][:value]
      assert_equal ['Inhaltstypen > Article'], by_method['with_content_classification_paths'][:value]
    end

    test 'limited_by_warning returns nil when no limit is configured' do
      assert_nil limited_by_warning({}, { 'ui' => { 'edit' => { 'options' => {} } } }, 'name', 'reached')
    end

    test 'object_browser_new_form_parameters returns nil when the stored filter has no usable filters' do
      assert_nil object_browser_new_form_parameters({ base: 1 }, { 'stored_filter' => [{}] })
    end

    test 'object_browser_new_form_parameters returns nil when no creatable template matches' do
      @creatable_templates = []

      assert_nil object_browser_new_form_parameters({ base: 1 }, definition_with_filters)
    end

    test 'object_browser_new_form_parameters merges the single matching template' do
      @creatable_templates = ['POI']

      result = object_browser_new_form_parameters({ base: 1 }, definition_with_filters)

      assert_equal 'POI', result[:template]
      assert_equal 1, result[:base]
    end

    test 'object_browser_new_form_parameters returns the query filter for multiple templates' do
      @creatable_templates = ['POI', 'Article']

      result = object_browser_new_form_parameters({ base: 1 }, definition_with_filters)

      assert_predicate result[:query_methods], :present?
    end

    test 'object_browser_new_form_parameters finds a template by name' do
      template_name = DataCycleCore::ThingTemplate.first.template_name

      result = object_browser_new_form_parameters({ base: 1 }, { 'template_name' => template_name })

      assert_equal template_name, result[:template].template_name
      assert_equal 1, result[:base]
    end

    test 'object_browser_new_form_parameters returns nil for an unknown template name' do
      assert_nil object_browser_new_form_parameters({}, { 'template_name' => 'NotARealTemplate' })
    end

    test 'limited_by_warning returns nil when no matching translation exists' do
      definition = { 'ui' => { 'edit' => { 'options' => { 'limited_by' => 'aggregate' } } } }
      key = struct_double(attribute_name_from_key: 'no_such_attribute')

      assert_nil limited_by_warning(struct_double(template_name: 'NoSuchTemplate'), definition, key, 'no_such_key')
    end

    test 'limited_by_warning falls back to the generic translation' do
      definition = { 'ui' => { 'edit' => { 'options' => { 'limited_by' => 'aggregate' } } } }
      key = struct_double(attribute_name_from_key: 'no_such_attribute')

      result = limited_by_warning(struct_double(template_name: 'NoSuchTemplate'), definition, key, 'filter_warning')

      assert_equal I18n.t('object_browser.limited_by.filter_warning', locale: :de), result
    end

    test 'limited_by_warning uses the most specific translation when present' do
      definition = { 'ui' => { 'edit' => { 'options' => { 'limited_by' => 'aggregate' } } } }
      key = struct_double(attribute_name_from_key: 'my_attribute')
      specific = 'object_browser.limited_by.Event.my_attribute.filter_warning'

      I18n.stub(:exists?, ->(*args, **_kw) { args.first.to_s == specific }) do
        assert_kind_of String, limited_by_warning(struct_double(template_name: 'Event'), definition, key, 'filter_warning')
      end
    end

    test 'limited_by_warning uses the attribute-level translation when present' do
      definition = { 'ui' => { 'edit' => { 'options' => { 'limited_by' => 'aggregate' } } } }
      key = struct_double(attribute_name_from_key: 'my_attribute')
      attribute_level = 'object_browser.limited_by.my_attribute.filter_warning'

      I18n.stub(:exists?, ->(*args, **_kw) { args.first.to_s == attribute_level }) do
        assert_kind_of String, limited_by_warning(struct_double(template_name: 'Event'), definition, key, 'filter_warning')
      end
    end
  end
end

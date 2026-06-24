# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ObjectBrowserHelperTest < ActionView::TestCase
    include DataCycleCore::ObjectBrowserHelper
    include DataCycleCore::UiLocaleHelper

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
  end
end

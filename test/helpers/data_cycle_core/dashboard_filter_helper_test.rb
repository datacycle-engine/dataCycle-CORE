# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DashboardFilterHelperTest < ActionView::TestCase
    include DataCycleCore::DashboardFilterHelper
    include DataCycleCore::UiLocaleHelper

    test 'advanced_attribute_filter_options returns the operators for each advanced type' do
      assert_equal 6, advanced_attribute_filter_options('string').size
      assert_equal 4, advanced_attribute_filter_options('classification_alias_ids').size
      assert_nil advanced_attribute_filter_options('boolean')
      assert_equal 2, advanced_attribute_filter_options('something_else').size
    end

    test 'advanced_relation_filter_options adds equal/not_equal for thing filters' do
      assert_includes advanced_relation_filter_options('i'), 'value="i"'
      assert_not_includes advanced_relation_filter_options('i'), 'value="s"'
      assert_includes advanced_relation_filter_options('s', true), 'value="s"'
    end

    test 'related_to_filter_options offers the related-to operators' do
      html = related_to_filter_options('i')

      assert_includes html, 'value="i"'
      assert_includes html, 'value="b"'
    end

    test 'advanced_graph_filter_options is restricted by the filter type' do
      html = advanced_graph_filter_options('i', 'items_linked_to')

      assert_includes html, 'value="i"'
      assert_includes html, 'value="s"'
      assert_includes html, 'value="p"'
    end

    test 'graph_filter_icon picks the linked or inverse icon' do
      assert_includes graph_filter_icon('name', 'linked_items_in'), 'type-linked'
      assert_includes graph_filter_icon('name', 'linked_items_in'), 'key-name'
      assert_includes graph_filter_icon('name', 'items_linked_to'), 'type-linked-inverse'
    end

    test 'selected_filter_params maps the filter category to button config' do
      assert_equal({ buttons: false, container_classes: 'user-force-filter' }, selected_filter_params({ 'c' => 'uf' }, {}))
      assert_equal({ buttons: 'a', container_classes: 'advanced-tags' }, selected_filter_params({ 'c' => 'a' }, {}))
      assert_equal({ buttons: false }, selected_filter_params({ 'c' => 'p' }, {}))
      assert_equal({ buttons: 'd' }, selected_filter_params({ 'c' => 'x' }, {}))
      assert_equal({ buttons: 'h', container_classes: 'hidden-filter' }, selected_filter_params({ 'c' => 'd' }, { hidden_filter: [{ 'c' => 'd' }] }))
    end

    test 'filter_to_hidden_fields renders nested hidden fields' do
      assert_includes filter_to_hidden_fields('f', 'val'), 'value="val"'
      assert_includes filter_to_hidden_fields('f', ['a', 'b']), 'name="f[]"'
      assert_includes filter_to_hidden_fields('f', { 'x' => 'y' }), 'name="f[x]"'
    end

    test 'conditional_filter_accordion wraps the block in a section or accordion' do
      assert_nil conditional_filter_accordion({ filter: nil }) { 'body' }
      assert_includes conditional_filter_accordion({ filter: 'present' }) { 'body' }, '<section'
      assert_includes conditional_filter_accordion({ filter: 'present', collapse: 'open' }) { 'body' }, 'accordion'
    end

    test 'the id-to-value helpers return empty for blank values' do
      assert_equal [], union_ids_to_value(nil)
      assert_equal [], thing_ids_to_value(nil)
      assert_nil union_values_to_options(nil)
      assert_nil thing_values_to_options(nil)
      assert_nil relation_filter_items('value', 'p')
    end

    test 'in_schedule_tag_title falls back to the filter translation' do
      assert_predicate in_schedule_tag_title('other', 'Title', 'key'), :present?
      assert_equal 'mykey', in_schedule_tag_title('in_schedule', 'Title', 'mykey')
    end

    test 'in_schedule_filter_title renders a span for non schedule filters' do
      assert_includes in_schedule_filter_title('other', 'name', 'Title', 'identifier'), '<span'
    end
  end
end

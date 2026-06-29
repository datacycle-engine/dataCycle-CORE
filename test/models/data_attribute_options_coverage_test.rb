# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the DataAttributeOptions struct value object - the overlay/aggregate
  # duplication helpers and the editor css/partial enrichment, which are pure logic
  # over the definition hash plus a content collaborator. The content and user are
  # lightweight doubles (dc_deep_dup keeps non-Hash/Array values by reference, so the
  # doubles survive the duplicate_options_for_attribute_name re-instantiation).
  class DataAttributeOptionsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def content_double(properties: {}, aggregate_names: [], overlay_names: [], external: false, aggregate_type_aggregate: false)
      props = properties.transform_keys(&:to_s)
      Class.new {
        define_method(:property?) { |name| props.key?(name.to_s) }
        define_method(:properties_for) { |name| props[name.to_s] || {} }
        define_method(:aggregate_property_names_for) { |_name, _include_overlay = false| aggregate_names }
        define_method(:overlay_property_names_for) { |_name, **| overlay_names }
        define_method(:external?) { external }
        define_method(:aggregate_type_aggregate?) { aggregate_type_aggregate }
        define_method(:embedded?) { false }
      }.new
    end

    def user_double(can_attribute: true)
      Class.new {
        define_method(:can_attribute?) { |_options| can_attribute }
      }.new
    end

    test 'initialize falls back to an empty definition when there is no content or hash' do
      options = DataCycleCore::DataAttributeOptions.new(key: 'name')

      assert_equal({}, options.definition)
    end

    test 'specific_scope returns the edit_scope as a string' do
      options = DataCycleCore::DataAttributeOptions.new(key: 'name', parameters: { options: { edit_scope: 'edit' } })

      assert_equal 'edit', options.specific_scope
    end

    test 'duplicate_options_for_attribute_name and the aggregate/overlay/original key helpers' do
      content = content_double(
        properties: { 'name' => { 'type' => 'string' }, 'agg_name' => { 'type' => 'string' }, 'overlay_name' => { 'type' => 'string' } },
        aggregate_names: ['agg_name'],
        overlay_names: ['overlay_name']
      )
      options = DataCycleCore::DataAttributeOptions.new(key: 'name', content:, definition: { 'type' => 'string' })

      # nil when the content does not have the attribute
      assert_nil options.duplicate_options_for_attribute_name('missing')

      duplicate = options.duplicate_options_for_attribute_name('agg_name')

      assert_kind_of DataCycleCore::DataAttributeOptions, duplicate
      assert_equal 'agg_name', duplicate.key

      aggregates = options.options_for_aggregate_keys

      assert_equal 1, aggregates.size
      assert_equal :update, aggregates.first.scope

      overlays = options.options_for_overlay_keys

      assert_equal 1, overlays.size
      assert_equal :update, overlays.first.scope

      original_options = DataCycleCore::DataAttributeOptions.new(
        key: 'agg_name', content:, definition: { 'features' => { 'aggregate' => { 'aggregate_for' => 'name' } } }
      )

      assert_kind_of DataCycleCore::DataAttributeOptions, original_options.options_for_original_key
    end

    test 'add_additional_attribute_properties! pushes overlay/aggregate css classes when value is present' do
      definition = {
        'features' => {
          'overlay' => { 'overlay_for' => 'x', 'overlay_type' => 'translation' },
          'aggregate' => { 'aggregate_for' => 'y' }
        }
      }
      options = DataCycleCore::DataAttributeOptions.new(
        key: 'name', definition:, value: 'present-value', parameters: { options: { class: 'foo' } }
      )

      options.add_additional_attribute_properties!
      classes = options.parameters[:options][:class].split

      assert_includes classes, 'dc-overlay'
      assert_includes classes, 'dc-aggregate'
      assert_includes classes, 'dc-overlay-visible'
      assert_includes classes, 'dc-aggregate-visible'
    end

    test 'add_additional_attribute_partials! adds overlay and aggregate partials when allowed' do
      content = content_double(
        properties: { 'name' => { 'type' => 'string' }, 'ov' => { 'type' => 'string' }, 'ag' => { 'type' => 'string' } },
        overlay_names: ['ov'],
        aggregate_names: ['ag'],
        external: true
      )
      definition = { 'features' => { 'overlay' => { 'allowed' => true }, 'aggregate' => { 'allowed' => true } } }
      options = DataCycleCore::DataAttributeOptions.new(
        key: 'name', content:, definition:, user: user_double(can_attribute: true),
        parameters: { options: { edit_scope: 'edit', class: 'existing-class' } }
      )

      assert_predicate options, :attribute_overlay_allowed?
      assert_predicate options, :attribute_aggregate_allowed?

      options.add_additional_attribute_partials!
      partials = options.parameters[:options][:additional_attribute_partials]

      assert_equal 2, partials.size
      assert_equal(['overlay', 'aggregate'], partials.map { |partial| partial[:locals][:key_prefix] })

      # the computed css classes are persisted back onto the options (and the
      # pre-existing class is preserved, not clobbered)
      classes = options.parameters[:options][:class].split

      assert_includes classes, 'existing-class'
      assert_includes classes, 'dc-has-additional-attribute-partial'
      assert_includes classes, 'dc-has-overlay'
      assert_includes classes, 'dc-has-aggregate'
    end

    test 'attribute_group_params returns the editor partial path and render params' do
      options = DataCycleCore::DataAttributeOptions.new(key: 'name', definition: {}, context: :editor)

      partial, params = options.attribute_group_params

      assert_equal 'data_cycle_core/contents/editors/attribute_group', partial
      assert_kind_of Hash, params
    end
  end
end

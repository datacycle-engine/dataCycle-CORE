# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AttributeEditorHelperTest < ActionView::TestCase
    include DataCycleCore::AttributeEditorHelper
    include DataCycleCore::UiLocaleHelper

    test 'schedule_duration_values maps duration parts onto their unit maxima' do
      result = schedule_duration_values('PT2H30M')

      assert_equal 24, result[:hours][:max]
      assert_equal 2, result[:hours][:value]
      assert_equal 30, result[:minutes][:value]
    end

    test 'sanitized_rich_text is nil for blank input and strips disallowed tags' do
      assert_nil sanitized_rich_text('')

      html = sanitized_rich_text('<b>hi</b><script>alert(1)</script>')

      assert_includes html, 'hi'
      assert_not_includes html, '<script'
      assert_predicate html, :html_safe?
    end

    test 'embedded_key_prefix builds the indexed datahash prefix' do
      assert_equal 'image[2][datahash]', embedded_key_prefix('image', 2)
    end

    test 'nested_definition only injects readonly when requested' do
      assert_equal({ 'type' => 'string' }, nested_definition({ 'type' => 'string' }, {}))
      assert nested_definition({ 'type' => 'string' }, { readonly: true }).dig('ui', 'edit', 'readonly')
    end

    test 'nested_options carries prefix and readonly into the edit options' do
      assert_equal 'p', nested_options({}, { prefix: 'p' })[:prefix]

      result = nested_options({ 'ui' => { 'edit' => { 'options' => { 'foo' => 'bar' } } } }, { prefix: 'p', readonly: true })

      assert_equal 'bar', result['foo']
      assert result[:readonly]
    end

    test 'attribute_validation_classes lists a class per validation' do
      assert_equal [], attribute_validation_classes({})
      assert_equal ['validation-container', 'validate-required', 'validate-min'], attribute_validation_classes({ 'validations' => { 'required' => true, 'min' => 1 } })
    end

    test 'merge_class_in_options appends without mutating the original options' do
      assert_equal({ 'class' => 'foo' }, merge_class_in_options(nil, 'foo'))

      original = { 'class' => 'a' }

      assert_equal({ 'class' => 'a b' }, merge_class_in_options(original, 'b'))
      assert_equal 'a', original['class']
    end

    test 'required_field_marker? checks for required-style validations' do
      assert_not required_field_marker?(nil)
      assert_not required_field_marker?({})
      assert_not required_field_marker?({ 'validations' => { 'max' => 5 } })
      assert required_field_marker?({ 'validations' => { 'required' => true } })
    end

    test 'additional_attribute_partial_type_key targets translations or datahash' do
      translatable = Object.new
      def translatable.attribute_translatable?(_key) = true
      untranslatable = Object.new
      def untranslatable.attribute_translatable?(_key) = false

      assert_equal 'thing[datahash][name]', additional_attribute_partial_type_key(untranslatable, 'name')
      assert_match(/\Athing\[translations\]\[\w+\]\[name\]\z/, additional_attribute_partial_type_key(translatable, 'name'))
    end

    test 'overlay_types and aggregate_types return check box structs' do
      assert(overlay_types({ 'type' => 'string' }).all? { |c| c.respond_to?(:value) })
      assert_equal 1, aggregate_types({}).size
      assert_respond_to aggregate_types({}).first, :value
    end
  end
end

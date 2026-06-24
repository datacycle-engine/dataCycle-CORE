# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AttributeViewerHelperTest < ActionView::TestCase
    include DataCycleCore::AttributeViewerHelper
    include DataCycleCore::UiLocaleHelper

    LifeCycleDouble = Struct.new(:editable, :stage_index) do
      def life_cycle_stage?(_id) = false
      def life_cycle_editable? = editable
      def life_cycle_stage_index(_id = nil) = stage_index
    end

    def can?(*) = true

    test 'contextual_content prefers a thing parent, then a thing content' do
      thing = DataCycleCore::Thing.new(template_name: 'Artikel')

      assert_equal thing, contextual_content({ parent: thing })
      assert_equal thing, contextual_content({ content: thing })
      assert_nil contextual_content({ parent: 'x', content: 'y' })
    end

    test 'attribute_value_present? delegates to DataHashService' do
      assert attribute_value_present?('x')
      assert_not attribute_value_present?('')
      assert_not attribute_value_present?(nil)
    end

    test 'attribute_viewer_html_classes builds detail classes from key and type' do
      assert_equal 'detail-type name string', attribute_viewer_html_classes(key: 'name', definition: { 'type' => 'string' }, options: {})
    end

    test 'attribute_viewer_html_classes adds the ui show type' do
      classes = attribute_viewer_html_classes(key: 'name', definition: { 'type' => 'string', 'ui' => { 'show' => { 'type' => 'headline' } } }, options: {})

      assert_includes classes, 'headline'
    end

    test 'attribute_viewer_html_classes flags changed attributes' do
      classes = attribute_viewer_html_classes(key: 'name', definition: { 'type' => 'string' }, options: { item_diff: ['~'] })

      assert_includes classes, 'has-changes edit'
    end

    test 'attribute_viewer_data_attributes builds the data hash with a given label' do
      result = attribute_viewer_data_attributes(key: 'name', definition: {}, data_attributes: { 'foo' => 'bar' }, data_label: 'My Label')

      assert_equal 'My Label', result[:label]
      assert_equal 'name', result[:key]
      assert_equal 'bar', result['foo']
    end

    test 'life_cycle_class disables the button when the stage is not editable' do
      classes = life_cycle_class(LifeCycleDouble.new(false, nil), { id: 1 })

      assert_includes classes, 'hollow button'
      assert_includes classes, 'disabled'
    end
  end
end

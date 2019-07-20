# frozen_string_literal: true

require 'test_helper'
require 'minitest/autorun'

ALL_SIMPLE_PROPERTIES = {
  'string_property' => {
    'label' => 'String',
    'type' => 'string'
  },
  'datetime_property' => {
    'label' => 'DateTime',
    'type' => 'datetime'
  },
  'number_property' => {
    'label' => 'Number',
    'type' => 'number'
  }
}.freeze

module DataCycleCore
  class TemplateTest < ActiveSupport::TestCase
    test 'DataCycleCore::Template should provide list of available content types' do
      template = Schema::Template.new({ 'schema_type' => 'Test', 'properties' => ALL_SIMPLE_PROPERTIES })

      assert_equal(3, template.property_definitions.count)
      assert_equal(
        ['stringProperty', 'datetimeProperty', 'numberProperty'].sort,
        template.property_definitions.map { |d| d[:label] }.sort
      )
      assert_equal(['Test', 'Test', 'Test'], template.property_definitions.map { |d| d[:domain] })
      assert_equal(template.property_definitions.find { |d| d[:label] == 'stringProperty' }[:range], '//schema.org/Text')
      assert_equal(template.property_definitions.find { |d| d[:label] == 'datetimeProperty' }[:range], '//schema.org/DateTime')
      assert_equal(template.property_definitions.find { |d| d[:label] == 'numberProperty' }[:range], '//schema.org/Number')
    end
  end
end

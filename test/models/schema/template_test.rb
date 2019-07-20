# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Schema::Template do
  describe 'for simple properties' do
    subject do
      DataCycleCore::Schema::Template.load_template(
        File.expand_path('../../data_types/simple_valid_templates/AllSimplePropertyTypes.yml', __dir__)
      )
    end

    it 'should exclude properties which are disabled for api' do
      subject.property_definitions.map { |d| d[:label] }.wont_include('disabledProperty')
    end

    it 'should contain 3 property definitions' do
      subject.property_definitions.count.must_equal(3)
      subject.property_definitions.map { |d| d[:label] }.sort.must_equal(
        ['stringProperty', 'datetimeProperty', 'numberProperty'].sort
      )
    end

    it 'should contain correct property definition for "stringProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'stringProperty' }

      string_property[:domain].must_equal('Thing_WithAllSimplePropertyTypes')
      string_property[:range].must_equal('//schema.org/Text')
    end

    it 'should contain correct property definition for "datetimeProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'datetimeProperty' }

      string_property[:domain].must_equal('Thing_WithAllSimplePropertyTypes')
      string_property[:range].must_equal('//schema.org/DateTime')
    end

    it 'should contain correct property definition for "numberProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'numberProperty' }

      string_property[:domain].must_equal('Thing_WithAllSimplePropertyTypes')
      string_property[:range].must_equal('//schema.org/Number')
    end
  end

  describe 'for simple embedded container' do
    subject do
      DataCycleCore::Schema.load_schema(
        File.expand_path('../../data_types/simple_valid_templates/SimpleEmbeddedContainer.yml', __dir__)
      ).template_by_schema_name('Thing_ActingAsEmbeddedContainer')
    end

    it 'should contain correct property definition for "embedded"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'embedded' }

      string_property[:domain].must_equal('Thing_ActingAsEmbeddedContainer')
      string_property[:range].must_equal('/schema/Thing_SimpleEmbedded')
    end
  end
end

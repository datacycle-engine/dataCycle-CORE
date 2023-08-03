# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Schema::Template do
  include DataCycleCore::MinitestSpecHelper

  describe 'for simple properties' do
    subject do
      DataCycleCore::Schema::Template.load_template(
        File.expand_path('../../data_types/simple_valid_templates/AllSimplePropertyTypes.yml', __dir__)
      )
    end

    it 'should exclude properties which are disabled for api' do
      assert(subject.property_definitions.pluck(:label).exclude?('disabledProperty'))
    end

    it 'should contain 4 property definitions' do
      assert(subject.property_definitions.count, 3)
      assert(subject.property_definitions.pluck(:label).sort, ['stringProperty', 'datetimeProperty', 'dateProperty', 'numberProperty'])
    end

    it 'should contain correct property definition for "stringProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'stringProperty' }

      assert(string_property[:template_type], 'Thing_WithAllSimplePropertyTypes')
      assert(string_property[:data_type], '//schema.org/Text')
    end

    it 'should contain correct property definition for "datetimeProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'datetimeProperty' }

      assert(string_property[:template_type], 'Thing_WithAllSimplePropertyTypes')
      assert(string_property[:data_type], '//schema.org/DateTime')
    end

    it 'should contain correct property definition for "dateProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'dateProperty' }

      assert(string_property[:template_type], 'Thing_WithAllSimplePropertyTypes')
      assert(string_property[:data_type], '//schema.org/Date')
    end

    it 'should contain correct property definition for "numberProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'numberProperty' }

      assert(string_property[:template_type], 'Thing_WithAllSimplePropertyTypes')
      assert(string_property[:data_type], '//schema.org/Number')
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

      assert(string_property[:template_type], 'Thing_ActingAsEmbeddedContainer')
      assert(string_property[:data_type], '/schema/Thing_SimpleEmbedded')
    end
  end

  describe 'for simple linked entites' do
    subject do
      DataCycleCore::Schema.load_schema(
        File.expand_path('../../data_types/simple_valid_templates/SimpleLinkedEntities.yml', __dir__)
      ).template_by_schema_name('Thing_SimpleEntityLinkedOne')
    end

    it 'should contain correct property definition for linked properties based on templates' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'linkedWithTemplate' }

      assert(string_property[:template_type], 'Thing_SimpleEntityLinkedOne')
      assert(string_property[:data_type], '/schema/Thing_SimpleEntityLinkedTwo')
    end

    it 'should contain correct property definition for linked properties based on templates' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'linkedWithStoredFilter' }

      assert(string_property[:template_type], 'Thing_SimpleEntityLinkedOne')
      assert(string_property[:data_type], '//schema.org/Thing')
    end
  end

  describe 'for simple embedded object' do
    subject do
      DataCycleCore::Schema.load_schema(
        File.expand_path('../../data_types/simple_valid_templates/EntityWithNestedObject.yml', __dir__)
      ).template_by_schema_name('Thing_Container')
    end

    it 'should expand nested properties' do
      assert(subject.property_definitions.count, 2)
      assert(subject.property_definitions.pluck(:label).sort, ['someProperty', 'anotherProperty'].sort)
    end

    it 'should contain correct property definition for "someProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'someProperty' }

      assert(string_property[:template_type], 'Thing_Container')
      assert(string_property[:data_type], '//schema.org/Text')
    end

    it 'should contain correct property definition for "anotherProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'anotherProperty' }

      assert(string_property[:template_type], 'Thing_Container')
      assert(string_property[:data_type], '//schema.org/Number')
    end
  end
end

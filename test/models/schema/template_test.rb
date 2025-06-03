# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Schema::Template do
  include DataCycleCore::MinitestSpecHelper

  describe 'for simple properties' do
    subject do
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [Rails.root.join('..', 'data_types', 'simple_valid_templates')]
      )
      template = template_importer.templates.find { |t| t[:name] == 'All Simple Property Types' }
      DataCycleCore::Schema.new([DataCycleCore::Schema::Template.new(template[:data].as_json)]).template_by_template_name('All Simple Property Types')
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
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [Rails.root.join('..', 'data_types', 'simple_valid_templates')]
      )
      template = template_importer.templates.find { |t| t[:name] == 'Simple Embedded Container' }
      DataCycleCore::Schema.new([DataCycleCore::Schema::Template.new(template[:data].as_json)]).template_by_schema_name('Thing_ActingAsEmbeddedContainer')
    end

    it 'should contain correct property definition for "embedded"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'embedded' }

      assert(string_property[:template_type], 'Thing_ActingAsEmbeddedContainer')
      assert(string_property[:data_type], '/schema/Thing_SimpleEmbedded')
    end
  end

  describe 'for simple linked entites' do
    subject do
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [Rails.root.join('..', 'data_types', 'simple_valid_templates')]
      )
      template = template_importer.templates.find { |t| t[:name] == 'Simple Linked Entity One' }
      DataCycleCore::Schema.new([DataCycleCore::Schema::Template.new(template[:data].as_json)]).template_by_schema_name('Thing_SimpleEntityLinkedOne')
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
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [Rails.root.join('..', 'data_types', 'simple_valid_templates')]
      )
      template = template_importer.templates.find { |t| t[:name] == 'Container' }
      DataCycleCore::Schema.new([DataCycleCore::Schema::Template.new(template[:data].as_json)]).template_by_schema_name('Thing_Container')
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

  describe 'for simple linked inverse entites' do
    subject do
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [Rails.root.join('..', 'data_types', 'simple_valid_templates')]
      )
      template_importer.templates.find { |t| t[:name] == 'Simple Linked Entity Inverse' }
    end

    it 'should set correct visibilities for inverse linked properties' do
      props = subject.dig(:data, :properties).select { |_, v| v[:link_direction] == 'inverse' }

      assert(props.dig(:linked_with_template1_inverse, :ui, :edit, :disabled))
      assert(props.dig(:linked_with_template2_inverse, :ui, :edit, :disabled))
      assert_nil(props.dig(:linked_with_template3_inverse, :ui, :edit, :disabled))
      assert(props.dig(:linked_with_template4_inverse, :ui, :edit, :disabled))
      assert_nil(props.dig(:linked_with_template5_inverse, :ui, :edit, :disabled))
      assert_equal(false, props.dig(:linked_with_template6_inverse, :ui, :edit, :disabled))
    end
  end

  describe 'for extended templates, overwritten in project without extends' do
    subject do
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [
          Rails.root.join('..', 'data_types', 'parent_set1'),
          Rails.root.join('..', 'data_types', 'child_set1'),
          Rails.root.join('..', 'data_types', 'parent_set2'),
          Rails.root.join('..', 'data_types', 'child_set2')
        ]
      )
      template_importer.templates.find { |t| t[:name] == 'DummyTemplate' }
    end

    it 'should have the correct properties from project' do
      props = subject.dig(:data, :properties)
      assert(props.key?(:dummy2))
      assert_not(props.key?(:dummy1))
      assert_not(props.key?(:dummy_parent1))
      assert_not(props.key?(:dummy_parent2))
    end
  end

  describe 'for linked_in_text property' do
    subject do
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [
          Rails.root.join('..', 'data_types', 'data_definitions', 'data_cycle_test')
        ]
      )
      template_importer.templates
    end

    it 'should have the correct linked_in_text property with computed parameters' do
      props = subject.find { |t| t[:name] == 'Rezept' }.dig(:data, :properties)
      assert(props.key?(:linked_in_text))
      assert_equal(['text'], props.dig(:linked_in_text, :compute, :parameters))
      assert(subject.map { |s| s.dig(:data, :properties, :linked_to_text) }.all?(&:present?))
    end
  end
end

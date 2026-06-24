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
      assert_equal(5, subject.property_definitions.count)
      assert_equal(['dateProperty', 'datetimeProperty', 'linkedToText', 'numberProperty', 'stringProperty'], subject.property_definitions.pluck(:label).sort)
    end

    it 'should contain correct property definition for "stringProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'stringProperty' }

      assert_equal(['Thing_WithAllSimplePropertyTypes'], string_property[:template_type])
      assert_equal('//schema.org/Text', string_property[:data_type])
    end

    it 'should contain correct property definition for "datetimeProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'datetimeProperty' }

      assert_equal(['Thing_WithAllSimplePropertyTypes'], string_property[:template_type])
      assert_equal('//schema.org/DateTime', string_property[:data_type])
    end

    it 'should contain correct property definition for "dateProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'dateProperty' }

      assert_equal(['Thing_WithAllSimplePropertyTypes'], string_property[:template_type])
      assert_equal('date', string_property[:data_type])
    end

    it 'should contain correct property definition for "numberProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'numberProperty' }

      assert_equal(['Thing_WithAllSimplePropertyTypes'], string_property[:template_type])
      assert_equal('//schema.org/Number', string_property[:data_type])
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

      assert_equal(['Thing_ActingAsEmbeddedContainer'], string_property[:template_type])
      assert_equal('/schema/Simple Embedded', string_property[:data_type])
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

      assert_equal(['Thing_SimpleEntityLinkedOne'], string_property[:template_type])
      assert_equal('/schema/Simple Linked Entity Two', string_property[:data_type])
    end

    it 'should contain correct property definition for linked properties based on templates' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'linkedWithStoredFilter' }

      assert_equal(['Thing_SimpleEntityLinkedOne'], string_property[:template_type])
      assert_equal([], string_property[:data_type])
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
      assert_equal(3, subject.property_definitions.count)
      assert_equal(['anotherProperty', 'linkedToText', 'someProperty'].sort, subject.property_definitions.pluck(:label).sort)
    end

    it 'should contain correct property definition for "someProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'someProperty' }

      assert_equal(['Thing_Container'], string_property[:template_type])
      assert_equal('//schema.org/Text', string_property[:data_type])
    end

    it 'should contain correct property definition for "anotherProperty"' do
      string_property = subject.property_definitions.find { |d| d[:label] == 'anotherProperty' }

      assert_equal(['Thing_Container'], string_property[:template_type])
      assert_equal('//schema.org/Number', string_property[:data_type])
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
      assert_not(props.dig(:linked_with_template6_inverse, :ui, :edit, :disabled))
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

  describe 'for extended templates, with missing base template from same type when importing in wrong order' do
    subject do
      DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [
          Rails.root.join('..', 'data_types', 'parent_set2'),
          Rails.root.join('..', 'data_types', 'parent_set1')
        ]
      )
    end

    it 'should produce error for missing base template' do
      errors = subject.errors

      assert_equal(1, errors.count)
      assert_equal(
        'creative_works.DummyParent.extends => BaseTemplate missing for DummyParent, possibly wrong order of templates',
        errors.first
      )
    end
  end

  describe 'for normal templates, choosing correct file for environment' do
    subject do
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [
          Rails.root.join('..', 'data_types', 'environment_set')
        ]
      )
      template_importer.templates.find { |t| t[:name] == 'DummyParent' }
    end

    it 'should have the correct properties from environment' do
      props = subject.dig(:data, :properties)

      assert(props.key?(:name))
      assert(props.key?(:id))
      assert_not(props.key?(:dummy_parent1))
    end
  end

  describe 'for abstract templates' do
    subject do
      DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [Rails.root.join('..', 'data_types', 'abstract_set')]
      )
    end

    it 'should exclude abstract templates from importable templates' do
      assert_nil(subject.templates.find { |t| t[:name] == 'AbstractParent' })
    end

    it 'should exclude templates that explicitly mark themselves abstract even when extending another' do
      assert_nil(subject.templates.find { |t| t[:name] == 'ConcreteAbstractChild' })
    end

    it 'should include concrete children of abstract templates' do
      assert_predicate(subject.templates.find { |t| t[:name] == 'ConcreteChild' }, :present?)
    end

    it 'should not inherit the abstract flag via extends' do
      child = subject.templates.find { |t| t[:name] == 'ConcreteChild' }

      assert_not(child.dig(:data, :abstract))
    end

    it 'should inherit properties from the abstract base template' do
      props = subject.templates.find { |t| t[:name] == 'ConcreteChild' }.dig(:data, :properties)

      assert(props.key?(:abstract_prop))
      assert(props.key?(:child_prop))
      assert(props.key?(:id))
      assert(props.key?(:name))
    end

    it 'should not produce errors when an abstract template is present' do
      assert_empty(subject.errors)
    end
  end

  describe 'for abstract templates extended by themselves' do
    subject do
      DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [
          Rails.root.join('..', 'data_types', 'abstract_self_extend_set1'),
          Rails.root.join('..', 'data_types', 'abstract_self_extend_set2')
        ]
      )
    end

    it 'should preserve the abstract flag when a template extends itself' do
      assert_nil(subject.templates.find { |t| t[:name] == 'AbstractSelfExtend' })
    end

    it 'should not produce errors' do
      assert_empty(subject.errors)
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

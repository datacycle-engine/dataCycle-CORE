# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Schema::Template do
  include DataCycleCore::MinitestSpecHelper

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

  describe 'for the overlay template reference' do
    # A template that declares an overlay property (see Feature::Overlay) and one
    # that does not, both taken from the live test data definitions so the fixture
    # stays the single source of truth instead of an inline schema hash.
    def templates
      @templates ||= DataCycleCore::MasterData::Templates::TemplateImporter.new(
        template_paths: [Rails.root.join('..', 'data_types', 'data_definitions', 'data_cycle_test')]
      ).templates
    end

    # The configured overlay attribute key (e.g. "overlay") — never hard-coded so
    # the test tracks Feature::Overlay's configuration.
    def overlay_key
      DataCycleCore.features.dig('overlay', 'attribute_keys')&.first
    end

    def template_for(raw)
      DataCycleCore::Schema::Template.new(raw[:data].as_json)
    end

    it 'has a configured overlay attribute key to test against' do
      assert_predicate overlay_key, :present?, 'expected Feature::Overlay to configure an attribute key'
    end

    it 'returns the template name referenced by the overlay property' do
      raw = templates.find { |t| t.dig(:data, :properties, overlay_key.to_sym, :template_name).present? }

      assert_predicate(raw, :present?, 'expected a fixture template with an overlay property')

      expected = raw.dig(:data, :properties, overlay_key.to_sym, :template_name)

      assert_equal expected, template_for(raw).overlay_template_name(overlay_key)
    end

    it 'resolves to an actual template that exists in the schema' do
      raw = templates.find { |t| t.dig(:data, :properties, overlay_key.to_sym, :template_name).present? }
      overlay_name = template_for(raw).overlay_template_name(overlay_key)

      assert_includes templates.map { |t| t.dig(:data, :name) }, overlay_name
    end

    it 'returns nil for a template without an overlay property' do
      raw = templates.find { |t| t.dig(:data, :properties, overlay_key.to_sym).blank? }

      assert_predicate(raw, :present?, 'expected a fixture template without an overlay property')
      assert_nil template_for(raw).overlay_template_name(overlay_key)
    end

    it 'returns nil when the overlay key is blank' do
      raw = templates.find { |t| t.dig(:data, :properties, overlay_key.to_sym, :template_name).present? }
      template = template_for(raw)

      assert_nil template.overlay_template_name(nil)
      assert_nil template.overlay_template_name('')
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

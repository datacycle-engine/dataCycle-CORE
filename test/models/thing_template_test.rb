# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ThingTemplateTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @template = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel') || DataCycleCore::ThingTemplate.first
    end

    test 'thing templates are readonly' do
      assert_predicate(@template, :readonly?)
    end

    test 'computed_property_names returns distinct, sorted, top-level computed attributes' do
      names = DataCycleCore::ThingTemplate.computed_property_names

      assert_kind_of(Array, names)
      assert_equal(names.uniq, names)
      assert_equal(names.sort, names)
      assert(names.none? { |name| name.include?('.') }, 'expected only top-level (non-nested) property names')
    end

    test 'scopes build valid relations' do
      assert_kind_of(Array, DataCycleCore::ThingTemplate.with_default_data_type(['Artikel']).to_a)
      assert_kind_of(Array, DataCycleCore::ThingTemplate.without_default_data_type(['Artikel']).to_a)
      assert_kind_of(Array, DataCycleCore::ThingTemplate.with_schema_type('schema:Article').to_a)
      assert_kind_of(Array, DataCycleCore::ThingTemplate.without_schema_type('schema:Article').to_a)
      assert_kind_of(Array, DataCycleCore::ThingTemplate.with_schema_classification_paths(['Inhaltstypen']).to_a)
      assert_kind_of(Array, DataCycleCore::ThingTemplate.without_schema_classification_paths(['Inhaltstypen']).to_a)
      assert_kind_of(Array, DataCycleCore::ThingTemplate.with_content_classification_paths(['Inhaltstypen']).to_a)
      assert_kind_of(Array, DataCycleCore::ThingTemplate.without_content_classification_paths(['Inhaltstypen']).to_a)
    end

    test 'schema_sorted orders properties by sorting' do
      sorted = @template.schema_sorted

      assert(sorted.key?('properties'))
      assert_equal(@template.property_names.sort, sorted['properties'].keys.sort)
    end

    test 'all_templates indexes every template and sets thing counts' do
      all = @template.all_templates

      assert_kind_of(Hash, all)
      assert(all.key?(@template.template_name))
      assert_kind_of(Integer, all[@template.template_name].thing_count)
    end

    test 'thing_count returns the number of things for the template' do
      assert_kind_of(Integer, @template.thing_count)
    end

    test 'schema_as_json builds an annotated schema' do
      content = @template.schema_as_json

      assert(content.key?('properties'))
      assert(content.key?('api_schema_types'))
      assert(content.key?('thing_count'))
      @template.property_names.each do |property_name|
        assert(content['properties'][property_name].key?('api_name'))
      end
    end

    test 'class-level schema_as_json maps every template' do
      result = DataCycleCore::ThingTemplate.schema_as_json

      assert_kind_of(Array, result)
      assert_equal(DataCycleCore::ThingTemplate.count, result.size)
      assert(result.all? { |tt| tt.key?('properties') })
    end

    test 'schema_as_json marks already-visited embedded templates as recursive' do
      embedded_name = @template.template_thing.embedded_property_names.first

      assert_predicate(embedded_name, :present?, 'expected the test template to have an embedded property')

      embedded_templates = Array.wrap(@template.schema_sorted.dig('properties', embedded_name, 'template_name'))
      content = @template.schema_as_json(Set.new(embedded_templates))

      assert(content['properties'][embedded_name]['embedded_schema'].any? { |e| e['recursive'] })
    end

    test 'schema_types and schema_ancestors return arrays' do
      assert_kind_of(Array, @template.schema_types)
      assert_kind_of(Array, @template.schema_ancestors)
    end

    test 'class-level things returns the things of the scoped templates' do
      assert_kind_of(Integer, DataCycleCore::ThingTemplate.where(template_name: @template.template_name).things.count)
    end

    test 'translated_property_labels returns labelled keys for array attributes' do
      assert_empty(DataCycleCore::ThingTemplate.translated_property_labels(locale: :de, attributes: []))

      labels = DataCycleCore::ThingTemplate.translated_property_labels(locale: :de, attributes: ['name'])

      assert_kind_of(Array, labels)
    end

    test 'translated_property_labels resolves hash attributes scoped by template' do
      labels = DataCycleCore::ThingTemplate.translated_property_labels(
        locale: :de,
        attributes: { 'name' => [@template.template_name] }
      )

      assert_kind_of(Array, labels)
    end
  end
end

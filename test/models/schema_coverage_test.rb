# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for Schema and its nested Template: the Error value object, the
  # classification translator, resolve_data_type type branches (incl. the linked
  # stored_filter path via a schema double) and the class/instance query helpers.
  class SchemaCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Template = DataCycleCore::Schema::Template

    test 'Template::Error carries details in its message' do
      error = Template::Error.new('boom', { reason: 'x' })

      assert_equal({ reason: 'x' }, error.details)
      assert_includes(error.message, 'boom')
      assert_includes(error.message, 'ERROR:')
    end

    test 'classification_template_translator maps Organisation to Organization' do
      assert_equal('Organization', Template.new({}).send(:classification_template_translator, 'Organisation'))
    end

    test 'resolve_data_type resolves linked, classification and primitive types' do
      t = Template.new({})

      assert_equal('//schema.org/Thing', t.send(:resolve_data_type, { 'type' => 'linked' }))
      assert_equal('classification', t.send(:resolve_data_type, { 'type' => 'classification' }))
      assert_equal('//schema.org/Schedule', t.send(:resolve_data_type, { 'type' => 'schedule' }))
      assert_equal('//schema.org/line', t.send(:resolve_data_type, { 'type' => 'geographic' }))
    end

    test 'resolve_data_type resolves a linked stored_filter via the schema' do
      schema = Object.new
      schema.define_singleton_method(:template_by_classification) { |_aliases| ['Organisation', 'POI'] }
      t = Template.new({}, schema:)
      definition = { 'type' => 'linked', 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'aliases' => ['x'] } }] }

      assert_equal(['Organization', 'POI'], t.send(:resolve_data_type, definition))
    end

    test 'content_types returns the distinct template content types' do
      assert_kind_of(Array, DataCycleCore::Schema.content_types)
    end

    test 'templates_with_content_type queries templates by content type' do
      assert_respond_to(DataCycleCore::Schema.templates_with_content_type('poi'), :count)
    end

    test 'template_by_classification resolves content types from the classification tree' do
      name = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').first&.internal_name
      schema = DataCycleCore::Schema.load_schema_from_database

      assert_kind_of(Array, schema.template_by_classification([name].compact))
    end
  end
end

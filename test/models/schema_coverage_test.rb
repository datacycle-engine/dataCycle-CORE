# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for Schema and its nested Template: the Error value object and the
  # class/instance query helpers (content_types, templates_with_content_type,
  # template_by_classification).
  class SchemaCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Template = DataCycleCore::Schema::Template

    test 'Template::Error carries details in its message' do
      error = Template::Error.new('boom', { reason: 'x' })

      assert_equal({ reason: 'x' }, error.details)
      assert_includes(error.message, 'boom')
      assert_includes(error.message, 'ERROR:')
    end

    test 'content_types returns the distinct template content types' do
      assert_kind_of(Array, DataCycleCore::Schema.content_types)
    end

    test 'templates_with_content_type queries templates by content type' do
      assert_respond_to(DataCycleCore::Schema.templates_with_content_type('poi'), :count)
    end

    test 'template_by_classification resolves content types from the classification tree' do
      name = DataCycleCore::Concept.for_tree('Inhaltstypen').first&.internal_name
      schema = DataCycleCore::Schema.load_schema_from_database

      assert_kind_of(Array, schema.template_by_classification([name].compact))
    end
  end
end

# frozen_string_literal: true

require 'test_helper'
require DataCycleCore::Engine.root.join('db', 'data_migrate', '20260806110000_backfill_schema_type_classifications')

module DataCycleCore
  # [#47270] Content classified on the shared schema.org node (SchemaTypes > Organization) has to
  # end up on the template specific leaf below it (> dcls:Organization) - the leaf that the
  # Inhaltstypen mapping now points to.
  class BackfillSchemaTypeClassificationsMigrationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: 'backfill' })
      @node = DataCycleCore::Concept.by_full_paths('SchemaTypes > Organization').first
      @leaf = DataCycleCore::Concept.by_full_paths('SchemaTypes > Organization > dcls:Organization').first
    end

    def schema_type_ids
      DataCycleCore::ConceptContent.where(content_data_id: @content.id, relation: 'schema_types').pluck(:concept_id)
    end

    test 'moves schema_types from the schema.org node to the dcls: leaf of the content template' do
      DataCycleCore::ConceptContent.where(content_data_id: @content.id, relation: 'schema_types').update_all(concept_id: @node.id)

      assert_equal([@node.id], schema_type_ids)

      migration = BackfillSchemaTypeClassifications.new
      migration.suppress_messages { migration.up }

      assert_equal([@leaf.id], schema_type_ids)
      assert_includes(@content.reload.collected_concept_contents.where(link_type: 'direct').pluck(:concept_id), @leaf.id)
    end
  end
end

# frozen_string_literal: true

require 'test_helper'
require DataCycleCore::Engine.root.join('db', 'data_migrate', '20260806120000_remove_stale_schema_type_mappings')

module DataCycleCore
  # [#47270] Imported and hand-made mappings are concept_links without a marker, so the cleanup may
  # only remove the node mapping the YAMLs replaced by a dcls: leaf for the same Inhaltstyp - never
  # a mapping that is merely absent from the YAMLs.
  class RemoveStaleSchemaTypeMappingsMigrationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @source = DataCycleCore::Concept.by_full_paths('Inhaltstypen > Organisation').first
      @node = DataCycleCore::Concept.by_full_paths('SchemaTypes > Organization').first
      @leaf = DataCycleCore::Concept.by_full_paths('SchemaTypes > Organization > dcls:Organization').first
      # a schema.org node with dcls: leafs below it, none of them desired - the shape a mapping made in the UI has
      @hand_made = DataCycleCore::Concept.by_full_paths('SchemaTypes > Place').first

      DataCycleCore::ConceptLink.insert_all(
        [@node, @leaf, @hand_made].map { |concept| { parent_id: @source.id, child_id: concept.id, link_type: DataCycleCore::ConceptLink::LINK_TYPE_RELATED } },
        unique_by: :index_concept_links_on_parent_id_and_child_id
      )
    end

    def run_migration
      migration = RemoveStaleSchemaTypeMappings.new

      migration.stub(:desired_pairs, Set[[@source.id, @leaf.id]]) do
        perform_enqueued_jobs { migration.suppress_messages { migration.up } }
      end
    end

    def concept_ids_of(content, relation)
      DataCycleCore::ConceptContent.where(content_data_id: content.id, relation:).pluck(:concept_id)
    end

    test 'removes the node mapping superseded by its dcls: leaf and keeps the mapping absent from the YAMLs' do
      run_migration

      remaining = @source.mapped_concept_links.reload.pluck(:child_id)

      assert_not_includes(remaining, @node.id)
      assert_includes(remaining, @leaf.id)
      assert_includes(remaining, @hand_made.id)
    end

    # Content predating the schema_types property carries the schema.org node as a
    # universal_classification and has no schema_types row for BackfillSchemaTypeClassifications
    # (20260806110000) to move, so it matches its Inhaltstyp through that node alone.
    test 'gives content matching only through a universal classification on the node its dcls: leaf' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: 'legacy' })
      DataCycleCore::ConceptContent.where(content_data_id: content.id, relation: 'schema_types').delete_all
      DataCycleCore::ConceptContent.create!(content_data_id: content.id, concept_id: @node.id, relation: 'universal_classifications')

      run_migration

      assert_equal([@leaf.id], concept_ids_of(content, 'schema_types'))
      assert_includes(concept_ids_of(content, 'universal_classifications'), @node.id)
      assert_includes(content.reload.collected_concept_contents.where(link_type: 'direct').pluck(:concept_id), @leaf.id)
    end
  end
end

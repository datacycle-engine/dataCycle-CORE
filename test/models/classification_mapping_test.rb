# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationMappingTest < ActiveSupport::TestCase
    def setup
      @classification_tree_label = DataCycleCore::ClassificationTreeLabel.create!(name: 'Test Label 1')
      @classification_alias1 = DataCycleCore::ClassificationAlias.create!(name: 'Test Alias 1')
      @classification1 = DataCycleCore::Classification.create!(name: 'Test Classificaion 1')
      @classification_group1 = DataCycleCore::ClassificationGroup.create!(
        classification: @classification1,
        classification_alias: @classification_alias1
      )
      @classification_tree1 = DataCycleCore::ClassificationTree.create!({
        classification_tree_label: @classification_tree_label,
        parent_classification_alias: nil,
        sub_classification_alias: @classification_alias1
      })
      @classification_alias2 = DataCycleCore::ClassificationAlias.create!(name: 'Test Alias 2')
      @classification2 = DataCycleCore::Classification.create!(name: 'Test Classificaion 2')
      @classification_group2 = DataCycleCore::ClassificationGroup.create!(
        classification: @classification2,
        classification_alias: @classification_alias2
      )
      @classification_tree2 = DataCycleCore::ClassificationTree.create!({
        classification_tree_label: @classification_tree_label,
        parent_classification_alias: nil,
        sub_classification_alias: @classification_alias2
      })
    end

    test 'destroy classification including aliases and groups' do
      @classification_tree1.destroy

      assert_predicate @classification1.reload, :destroyed?
      assert_predicate @classification_alias1.reload, :destroyed?
      assert_predicate @classification_group1.reload, :destroyed?
      assert_not @classification2.reload.destroyed?
      assert_not @classification_alias2.reload.destroyed?
      assert_not @classification_group2.reload.destroyed?
    end

    test 'destroy classification with mappings including aliases and groups' do
      @classification_alias1.update(classification_ids: [@classification1.id, @classification2.id])
      @classification_tree1.destroy

      assert_predicate @classification1.reload, :destroyed?
      assert_predicate @classification_alias1.reload, :destroyed?
      assert_predicate @classification_group1.reload, :destroyed?
      assert_not @classification2.reload.destroyed?
      assert_not @classification_alias2.reload.destroyed?
      assert_not @classification_group2.reload.destroyed?
    end

    test 'destroy classification with mappings from another alias including aliases and groups' do
      @classification_alias2.update(classification_ids: [@classification1.id, @classification2.id])
      @classification_tree1.destroy

      assert_predicate @classification1.reload, :destroyed?
      assert_predicate @classification_alias1.reload, :destroyed?
      assert_predicate @classification_group1.reload, :destroyed?
      assert_not @classification2.reload.destroyed?
      assert_not @classification_alias2.reload.destroyed?
      assert_not @classification_group2.reload.destroyed?
    end

    test 'destroy classification_tree_label with mappings' do
      @classification_tree_label.destroy

      assert_predicate @classification1.reload, :destroyed?
      assert_predicate @classification_alias1.reload, :destroyed?
      assert_predicate @classification_group1.reload, :destroyed?
      assert_predicate @classification2.reload, :destroyed?
      assert_predicate @classification_alias2.reload, :destroyed?
      assert_predicate @classification_group2.reload, :destroyed?
    end

    test 'destroy single classification_alias' do
      @classification_alias1.destroy

      assert_predicate @classification1.reload, :destroyed?
      assert_predicate @classification_alias1.reload, :destroyed?
      assert_predicate @classification_group1.reload, :destroyed?
    end

    test 'destroy multiple classification_aliases' do
      DataCycleCore::ClassificationAlias.for_tree(@classification_tree_label.name).destroy_all

      assert_predicate @classification1.reload, :destroyed?
      assert_predicate @classification_alias1.reload, :destroyed?
      assert_predicate @classification_group1.reload, :destroyed?
      assert_predicate @classification2.reload, :destroyed?
      assert_predicate @classification_alias2.reload, :destroyed?
      assert_predicate @classification_group2.reload, :destroyed?
    end

    # Redmine #51232: a concept claiming another concept's classification must not take it down.
    # classification_contents are hard-deleted, so the owner would lose its content assignments for
    # good.
    test 'destroy classification_alias sharing a classification keeps the classification' do
      thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel' })
      DataCycleCore::ClassificationContent.create!(content_data: thing, classification: @classification1, relation: 'test_relation')

      # concepts is trigger-maintained and readonly, so the hijacked claim is written past the model
      DataCycleCore::Concept.unscoped.where(id: @classification_alias2.id).update_all(classification_id: @classification1.id)

      @classification_alias2.reload.destroy

      assert_predicate @classification_alias2.reload, :destroyed?
      assert_not @classification1.reload.destroyed?
      assert_not @classification_group1.reload.destroyed?
      assert_equal 1, DataCycleCore::ClassificationContent.where(classification_id: @classification1.id).count
      assert_equal @classification1.id, @classification_alias1.reload.primary_classification&.id
    end

    # Redmine #51232: merging destroys the source, and the importer's ON CONFLICT only matches live
    # rows -- so without handing the external identity over, the next import recreates the source as a
    # new concept and the duplicate is back.
    test 'merge moves the external system and key to a target that has none' do
      es = DataCycleCore::ExternalSystem.first
      @classification_alias1.update!(external_source_id: es.id, external_key: 'MERGE-KEY')
      @classification1.update!(external_source_id: es.id, external_key: 'MERGE-KEY')

      @classification_alias1.merge_with_children(@classification_alias2)
      target = @classification_alias2.reload

      assert_equal es.id, target.external_source_id
      assert_equal 'MERGE-KEY', target.external_key
      assert_equal 'MERGE-KEY', target.primary_classification.external_key
      # update_concepts_trigger carries the alias write into the concepts row
      assert_equal 'MERGE-KEY', DataCycleCore::Concept.find(target.id).external_key
      assert_empty DataCycleCore::ClassificationAlias.where(external_source_id: es.id, external_key: 'MERGE-KEY').where.not(id: target.id)
    end

    test 'merge is refused when both sides carry an external system' do
      es = DataCycleCore::ExternalSystem.first
      @classification_alias1.update!(external_source_id: es.id, external_key: 'SOURCE-KEY')
      @classification_alias2.update!(external_source_id: es.id, external_key: 'TARGET-KEY')

      assert_raises DataCycleCore::Error::AmbiguousClassificationExternalSystemError do
        @classification_alias1.merge_with_children(@classification_alias2)
      end

      # nothing was destroyed on the way to the raise
      assert_not @classification_alias1.reload.destroyed?
      assert_equal 'TARGET-KEY', @classification_alias2.reload.external_key
    end

    # Redmine #51232: the source keeps its classification because another concept still claims it, so
    # the pair has to be released there before the target can take it --
    # index_classifications_unique_external_source_id_and_key is NULLS NOT DISTINCT on live rows.
    test 'merge releases the external key from a classification another concept still claims' do
      es = DataCycleCore::ExternalSystem.first
      @classification_alias1.update!(external_source_id: es.id, external_key: 'SHARED-KEY')
      @classification1.update!(external_source_id: es.id, external_key: 'SHARED-KEY')

      claimant = DataCycleCore::ClassificationAlias.create!(name: 'Test Alias 3')
      DataCycleCore::ClassificationTree.create!(classification_tree_label: @classification_tree_label, parent_classification_alias: nil, sub_classification_alias: claimant)
      # concepts is trigger-maintained and readonly, so the hijacked claim is written past the model
      DataCycleCore::Concept.unscoped.where(id: claimant.id).update_all(classification_id: @classification1.id)

      assert_nothing_raised { @classification_alias1.merge_with_children(@classification_alias2) }

      assert_equal 'SHARED-KEY', @classification_alias2.reload.primary_classification.external_key
      assert_not @classification1.reload.destroyed?
      assert_nil @classification1.external_source_id
      assert_nil @classification1.external_key
    end

    test 'merge keeps the target external system when the source only has an orphaned key' do
      es = DataCycleCore::ExternalSystem.first
      @classification_alias1.update!(external_key: 'SHARED-KEY')
      @classification_alias2.update!(external_source_id: es.id, external_key: 'SHARED-KEY')

      assert_nothing_raised { @classification_alias1.merge_with_children(@classification_alias2) }

      assert_equal es.id, @classification_alias2.reload.external_source_id
      assert_equal 'SHARED-KEY', @classification_alias2.external_key
    end

    # pins the source guard in move_external_system_to: an orphaned key is not an identity to hand
    # over, and the target here has no external system to stop the write further down.
    test 'merge keeps a config target key when the source only has an orphaned key' do
      @classification_alias1.update!(external_key: 'ORPHAN-KEY')
      @classification_alias2.update!(external_key: 'Test Label 1 > Probe System')

      assert_nothing_raised { @classification_alias1.merge_with_children(@classification_alias2) }

      assert_nil @classification_alias2.reload.external_source_id
      assert_equal 'Test Label 1 > Probe System', @classification_alias2.external_key
    end

    # Redmine #51232: a config concept is identified by (NULL, full_path) -- both unique indexes are
    # NULLS NOT DISTINCT and ConceptImporter#insert_concepts looks it up on that pair. Overwriting it
    # with the source's identity is what makes the next dc:update insert a second node.
    test 'merge is refused when the target carries an external key without a system' do
      es = DataCycleCore::ExternalSystem.first
      @classification_alias1.update!(external_source_id: es.id, external_key: 'EXT-123')
      @classification_alias2.update!(external_key: 'Test Label 1 > Probe System')

      assert_raises DataCycleCore::Error::AmbiguousClassificationExternalSystemError do
        @classification_alias1.merge_with_children(@classification_alias2)
      end

      assert_not @classification_alias1.reload.destroyed?
      assert_nil @classification_alias2.reload.external_source_id
      assert_equal 'Test Label 1 > Probe System', @classification_alias2.external_key
    end

    # pins the equal-pair return: only reachable with a NULL key on both sides, because the partial
    # unique index stops two live aliases from sharing a real one.
    # It is also the only path left into move_external_system_to with a target that has a system, so
    # the target guard is pinned here: without it the target's classification takes the source's over.
    test 'merge of an identical external system pair is allowed' do
      es = DataCycleCore::ExternalSystem.first
      @classification_alias1.update!(external_source_id: es.id)
      @classification_alias2.update!(external_source_id: es.id)

      assert_nothing_raised { @classification_alias1.merge_with_children(@classification_alias2) }

      assert_equal es.id, @classification_alias2.reload.external_source_id
      assert_nil @classification_alias2.external_key
      assert_nil @classification_alias2.primary_classification.external_source_id
    end

    # pins the external_key guard in release_external_system_from_primary_classification: with a NULL
    # key there is nothing the index could collide on, so the co-owner keeps its external system.
    # The co-owner is what makes the branch observable -- without one the classification is already
    # destroyed by the time move_external_system_to runs.
    test 'merge keeps the external system on a co-owned classification when the key is null' do
      es = DataCycleCore::ExternalSystem.first
      @classification_alias1.update!(external_source_id: es.id)
      @classification1.update!(external_source_id: es.id)

      claimant = DataCycleCore::ClassificationAlias.create!(name: 'Test Alias 3')
      DataCycleCore::ClassificationTree.create!(classification_tree_label: @classification_tree_label, parent_classification_alias: nil, sub_classification_alias: claimant)
      # concepts is trigger-maintained and readonly, so the hijacked claim is written past the model
      DataCycleCore::Concept.unscoped.where(id: claimant.id).update_all(classification_id: @classification1.id)

      assert_nothing_raised { @classification_alias1.merge_with_children(@classification_alias2) }

      assert_not @classification1.reload.destroyed?
      assert_equal es.id, @classification1.external_source_id
      assert_equal es.id, @classification_alias2.reload.external_source_id
    end

    test 'create mapping with create_mapping_for_path' do
      assert_equal [@classification1.id].to_set, @classification_alias1.reload.classification_ids.to_set

      @classification_alias1.create_mapping_for_path(@classification_alias2.full_path)

      assert_equal [@classification1.id, @classification2.id].to_set, @classification_alias1.reload.classification_ids.to_set
    end

    test 'custom_find_by_full_path' do
      assert_equal @classification_alias1.id, DataCycleCore::ClassificationAlias.custom_find_by_full_path(@classification_alias1.full_path)&.id
      assert_equal @classification_alias1.id, DataCycleCore::ClassificationAlias.custom_find_by_full_path!(@classification_alias1.full_path)&.id

      assert_nil DataCycleCore::ClassificationAlias.custom_find_by_full_path('NON > Existant > Path')

      assert_raises ActiveRecord::RecordNotFound do
        DataCycleCore::ClassificationAlias.custom_find_by_full_path!('NON > Existant > Path')
      end
    end
  end
end

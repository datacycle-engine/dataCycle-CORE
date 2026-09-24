# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Destroying and merging concepts. The classification/alias pair collapsed into one row, so what
  # used to be "a classification two aliases claim" cannot occur any more: a merge hard deletes the
  # source, which frees its (external_system_id, external_key) outright.
  class ConceptMergeTest < ActiveSupport::TestCase
    def setup
      @concept_scheme = DataCycleCore::ConceptScheme.create!(name: 'Test Label 1')
      @concept1 = @concept_scheme.concepts.create!(name: 'Test Concept 1')
      @concept2 = @concept_scheme.concepts.create!(name: 'Test Concept 2')
    end

    # concepts carry no deleted_at any more, so a destroy really removes the row
    test 'destroy a concept and leave its sibling' do
      @concept1.destroy

      assert_not DataCycleCore::Concept.exists?(@concept1.id)
      assert DataCycleCore::Concept.exists?(@concept2.id)
    end

    test 'destroy a concept takes its mappings with it' do
      @concept1.update!(mapped_concept_ids: [@concept2.id])
      link_id = @concept1.mapped_concept_links.first.id

      @concept1.destroy

      assert_not DataCycleCore::ConceptLink.exists?(link_id)
      assert DataCycleCore::Concept.exists?(@concept2.id)
    end

    test 'destroy the concept scheme takes its concepts with it' do
      @concept_scheme.destroy

      assert_empty DataCycleCore::Concept.where(id: [@concept1.id, @concept2.id])
    end

    test 'destroy every concept of a scheme' do
      DataCycleCore::Concept.for_tree(@concept_scheme.name).destroy_all

      assert_empty DataCycleCore::Concept.where(id: [@concept1.id, @concept2.id])
    end

    # Redmine #51232: merging destroys the source, and the importer's ON CONFLICT only matches live
    # rows -- so without handing the external identity over, the next import recreates the source as a
    # new concept and the duplicate is back.
    test 'merge moves the external system and key to a target that has none' do
      es = DataCycleCore::ExternalSystem.first
      @concept1.update!(external_system_id: es.id, external_key: 'MERGE-KEY')

      @concept1.merge_with_children(@concept2)
      target = @concept2.reload

      assert_equal es.id, target.external_system_id
      assert_equal 'MERGE-KEY', target.external_key
      assert_empty DataCycleCore::Concept.where(external_system_id: es.id, external_key: 'MERGE-KEY').where.not(id: target.id)
    end

    test 'merge is refused when the sides carry different external systems' do
      es = DataCycleCore::ExternalSystem.first
      other_es = DataCycleCore::ExternalSystem.create!(name: 'Merge Other System', identifier: 'merge-other-system')
      @concept1.update!(external_system_id: es.id, external_key: 'SOURCE-KEY')
      @concept2.update!(external_system_id: other_es.id, external_key: 'TARGET-KEY')

      assert_raises DataCycleCore::Error::AmbiguousConceptExternalSystemError do
        @concept1.merge_with_children(@concept2)
      end

      # nothing was destroyed on the way to the raise
      assert DataCycleCore::Concept.exists?(@concept1.id)
      assert_equal 'TARGET-KEY', @concept2.reload.external_key
    end

    # Two keys of one system are that system's own duplicate, which is what a merge is for. The
    # target keeps its key, so the system still imports the survivor; only the source key is lost.
    test 'merge of two keys from the same external system is allowed' do
      es = DataCycleCore::ExternalSystem.first
      @concept1.update!(external_system_id: es.id, external_key: 'SOURCE-KEY')
      @concept2.update!(external_system_id: es.id, external_key: 'TARGET-KEY')

      assert_nothing_raised { @concept1.merge_with_children(@concept2) }

      assert_not DataCycleCore::Concept.exists?(@concept1.id)
      assert_equal es.id, @concept2.reload.external_system_id
      assert_equal 'TARGET-KEY', @concept2.external_key
    end

    # This is the shape #51232's own duplicate has: a bare-keyed source merges into a system-keyed
    # target, let through by the first guard rather than by the same-system rule. The source row goes
    # for good, so 'SOURCE-KEY' is free again.
    test 'merge into a target with an external system is allowed when the source carries only a bare key' do
      es = DataCycleCore::ExternalSystem.first
      @concept1.update!(external_key: 'SOURCE-KEY')
      @concept2.update!(external_system_id: es.id, external_key: 'TARGET-KEY')

      assert_nothing_raised { @concept1.merge_with_children(@concept2) }

      assert_not DataCycleCore::Concept.exists?(@concept1.id)
      assert_empty DataCycleCore::Concept.where(external_key: 'SOURCE-KEY')
      assert_equal es.id, @concept2.reload.external_system_id
      assert_equal 'TARGET-KEY', @concept2.external_key
    end

    # A same-system target with no key of its own has the slot the source key needs free, so the
    # survivor stays importable under it. Gating on the target's external_system_id instead left
    # 'SOURCE-KEY' on no live row, and the next run inserted a concept for it again.
    test 'merge hands the source key to a same-system target that carries none' do
      es = DataCycleCore::ExternalSystem.first
      @concept1.update!(external_system_id: es.id, external_key: 'SOURCE-KEY')
      @concept2.update!(external_system_id: es.id)

      assert_nothing_raised { @concept1.merge_with_children(@concept2) }

      assert_equal es.id, @concept2.reload.external_system_id
      assert_equal 'SOURCE-KEY', @concept2.external_key
    end

    test 'merge keeps the target external system when the source only has an orphaned key' do
      es = DataCycleCore::ExternalSystem.first
      @concept1.update!(external_key: 'SHARED-KEY')
      @concept2.update!(external_system_id: es.id, external_key: 'SHARED-KEY')

      assert_nothing_raised { @concept1.merge_with_children(@concept2) }

      assert_equal es.id, @concept2.reload.external_system_id
      assert_equal 'SHARED-KEY', @concept2.external_key
    end

    # pins the source guard in move_external_system_to on its own: the target carries no identity at
    # all, so nothing further down would stop the write. A config concept is identified by
    # (NULL, full_path), and handing the source's over would point ConceptImporter#insert_concepts at
    # the target for a path the target does not have.
    test 'merge leaves an unkeyed target alone when the source only has an orphaned key' do
      @concept1.update!(external_key: 'ORPHAN-KEY')

      assert_nothing_raised { @concept1.merge_with_children(@concept2) }

      assert_nil @concept2.reload.external_system_id
      assert_nil @concept2.external_key
    end

    # both guards cover this one: the source has no system, and the target's key is taken.
    test 'merge keeps a config target key when the source only has an orphaned key' do
      @concept1.update!(external_key: 'ORPHAN-KEY')
      @concept2.update!(external_key: 'Test Label 1 > Probe System')

      assert_nothing_raised { @concept1.merge_with_children(@concept2) }

      assert_nil @concept2.reload.external_system_id
      assert_equal 'Test Label 1 > Probe System', @concept2.external_key
    end

    # Redmine #51232: a config concept is identified by (NULL, full_path) -- the unique index is
    # partial on external_key IS NOT NULL and ConceptImporter#insert_concepts looks it up on that
    # pair. Overwriting it with the source's identity is what makes the next dc:update insert a
    # second node.
    test 'merge is refused when the target carries an external key without a system' do
      es = DataCycleCore::ExternalSystem.first
      @concept1.update!(external_system_id: es.id, external_key: 'EXT-123')
      @concept2.update!(external_key: 'Test Label 1 > Probe System')

      assert_raises DataCycleCore::Error::AmbiguousConceptExternalSystemError do
        @concept1.merge_with_children(@concept2)
      end

      assert DataCycleCore::Concept.exists?(@concept1.id)
      assert_nil @concept2.reload.external_system_id
      assert_equal 'Test Label 1 > Probe System', @concept2.external_key
    end

    # the same-system return with equal keys, only reachable with a NULL key on both sides:
    # index_concepts_on_external_system_id_and_external_key is partial on external_key IS NOT NULL,
    # so two concepts cannot share a real key. It also pins the target guard in
    # move_external_system_to: without it the target would take the source's system over.
    test 'merge of an identical external system pair is allowed' do
      es = DataCycleCore::ExternalSystem.first
      @concept1.update!(external_system_id: es.id)
      @concept2.update!(external_system_id: es.id)

      assert_nothing_raised { @concept1.merge_with_children(@concept2) }

      assert_equal es.id, @concept2.reload.external_system_id
      assert_nil @concept2.external_key
    end

    test 'custom_find_by_full_path' do
      assert_equal @concept1.id, DataCycleCore::Concept.custom_find_by_full_path(@concept1.full_path)&.id
      assert_equal @concept1.id, DataCycleCore::Concept.custom_find_by_full_path!(@concept1.full_path)&.id

      assert_nil DataCycleCore::Concept.custom_find_by_full_path('NON > Existant > Path')

      assert_raises ActiveRecord::RecordNotFound do
        DataCycleCore::Concept.custom_find_by_full_path!('NON > Existant > Path')
      end
    end
  end
end

# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  # Redmine #47172/#50677 regression guard.
  #
  # The hidden-mapping exclusion must NOT live on the concepts association as a
  # reference to another table. Such a reference is unresolvable when the association is preloaded
  # with a custom scope, so ActiveRecord silently drops the scope — the event PDF serializer preloads
  # concepts restricted to a single tree via
  #   PreloadService.preload(query, :concepts, Concept.for_tree('...'))
  # and, once the scope is dropped, renders classifications from *every* tree.
  #
  # Keeping the exclusion on the classification_groups association (ConceptLink.visible, a
  # self-contained NOT EXISTS) leaves the concepts scope clean, so a scoped preload
  # stays intact while hidden mappings are still excluded through the through-join.
  class ConceptsScopePreloadTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      # content classified with one alias in each of two distinct trees
      tree_a = DataCycleCore::ConceptScheme.create!(name: "PreloadScopeA_#{SecureRandom.hex(6)}")
      @tree_a_name = tree_a.name
      @alias_a = tree_a.create_concept('A1')

      tree_b = DataCycleCore::ConceptScheme.create!(name: "PreloadScopeB_#{SecureRandom.hex(6)}")
      @alias_b = tree_b.create_concept('B1')

      @content = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: {
          name: 'ClassificationAliasesScopePreloadProbe',
          universal_classifications: [@alias_a.id, @alias_b.id]
        }
      )

      # content that receives a mapped alias which then gets hidden
      source_tree = DataCycleCore::ConceptScheme.create!(name: "PreloadHiddenSrc_#{SecureRandom.hex(6)}")
      @source_alias = source_tree.create_concept('SRC')
      @target_tree = DataCycleCore::ConceptScheme.create!(name: "PreloadHiddenTgt_#{SecureRandom.hex(6)}")
      @target_alias = @target_tree.create_concept('TGT')
      @mapping = DataCycleCore::ConceptLink.create!(parent: @target_alias, child: @source_alias, link_type: DataCycleCore::ConceptLink::LINK_TYPE_RELATED)

      @hidden_content = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: {
          name: 'ClassificationAliasesPreloadHiddenProbe',
          universal_classifications: [@source_alias.id]
        }
      )
      @target_tree.update!(hidden_mappings: true)
      @hidden_content.reload
    end

    # fresh instances so the association is not already loaded/memoized from the setup
    def reloaded(content)
      DataCycleCore::Thing.where(id: content.id).to_a
    end

    test 'an unscoped preload loads concepts from every tree' do
      records = reloaded(@content)
      DataCycleCore::PreloadService.preload(records, :concepts)

      assert_predicate records.first.association(:concepts), :loaded?
      ids = records.first.concepts.map(&:id)

      assert_includes ids, @alias_a.id
      assert_includes ids, @alias_b.id
    end

    test 'a tree-scoped preload keeps its scope and loads only that tree' do
      records = reloaded(@content)
      DataCycleCore::PreloadService.preload(records, :concepts, DataCycleCore::Concept.for_tree(@tree_a_name))

      # the preloaded target is read back as-is by callers (e.g. the PDF template); reading it must
      # not trigger an unscoped reload, and it must already be limited to tree A
      assert_predicate records.first.association(:concepts), :loaded?
      ids = records.first.concepts.map(&:id)

      assert_includes ids, @alias_a.id
      assert_not_includes ids, @alias_b.id, 'tree-scoped preload leaked classifications from another tree'
    end

    test 'a preload still excludes hidden mappings through the through-join' do
      records = reloaded(@hidden_content)
      DataCycleCore::PreloadService.preload(records, :concepts)

      ids = records.first.concepts.map(&:id)

      assert_includes ids, @source_alias.id
      assert_not_includes ids, @target_alias.id, 'hidden mapping leaked into the preloaded association'
    end
  end
end

# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  # Redmine #47172/#50677 regression guard.
  #
  # The hidden-mapping exclusion must NOT live on the classification_aliases association as a
  # reference to another table. Such a reference is unresolvable when the association is preloaded
  # with a custom scope, so ActiveRecord silently drops the scope — the event PDF serializer preloads
  # classification_aliases restricted to a single tree via
  #   PreloadService.preload(query, :classification_aliases, ClassificationAlias.for_tree('...'))
  # and, once the scope is dropped, renders classifications from *every* tree.
  #
  # Keeping the exclusion on the classification_groups association (ClassificationGroup.visible, a
  # self-contained NOT EXISTS) leaves the classification_aliases scope clean, so a scoped preload
  # stays intact while hidden mappings are still excluded through the through-join.
  class ClassificationAliasesScopePreloadTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      # content classified with one alias in each of two distinct trees
      tree_a = DataCycleCore::ClassificationTreeLabel.create!(name: "PreloadScopeA_#{SecureRandom.hex(6)}")
      @tree_a_name = tree_a.name
      @alias_a = tree_a.create_classification_alias('A1')

      tree_b = DataCycleCore::ClassificationTreeLabel.create!(name: "PreloadScopeB_#{SecureRandom.hex(6)}")
      @alias_b = tree_b.create_classification_alias('B1')

      @content = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: {
          name: 'ClassificationAliasesScopePreloadProbe',
          universal_classifications: [@alias_a.primary_classification.id, @alias_b.primary_classification.id]
        }
      )

      # content that receives a mapped alias which then gets hidden
      source_tree = DataCycleCore::ClassificationTreeLabel.create!(name: "PreloadHiddenSrc_#{SecureRandom.hex(6)}")
      @source_alias = source_tree.create_classification_alias('SRC')
      @target_tree = DataCycleCore::ClassificationTreeLabel.create!(name: "PreloadHiddenTgt_#{SecureRandom.hex(6)}")
      @target_alias = @target_tree.create_classification_alias('TGT')
      @mapping = DataCycleCore::ClassificationGroup.create!(classification: @source_alias.primary_classification, classification_alias: @target_alias)

      @hidden_content = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: {
          name: 'ClassificationAliasesPreloadHiddenProbe',
          universal_classifications: [@source_alias.primary_classification.id]
        }
      )
      @target_tree.update!(hidden_mappings: true)
      @hidden_content.reload
    end

    # fresh instances so the association is not already loaded/memoized from the setup
    def reloaded(content)
      DataCycleCore::Thing.where(id: content.id).to_a
    end

    test 'an unscoped preload loads classification_aliases from every tree' do
      records = reloaded(@content)
      DataCycleCore::PreloadService.preload(records, :classification_aliases)

      assert_predicate records.first.association(:classification_aliases), :loaded?
      ids = records.first.classification_aliases.map(&:id)

      assert_includes ids, @alias_a.id
      assert_includes ids, @alias_b.id
    end

    test 'a tree-scoped preload keeps its scope and loads only that tree' do
      records = reloaded(@content)
      DataCycleCore::PreloadService.preload(records, :classification_aliases, DataCycleCore::ClassificationAlias.for_tree(@tree_a_name))

      # the preloaded target is read back as-is by callers (e.g. the PDF template); reading it must
      # not trigger an unscoped reload, and it must already be limited to tree A
      assert_predicate records.first.association(:classification_aliases), :loaded?
      ids = records.first.classification_aliases.map(&:id)

      assert_includes ids, @alias_a.id
      assert_not_includes ids, @alias_b.id, 'tree-scoped preload leaked classifications from another tree'
    end

    test 'a preload still excludes hidden mappings through the through-join' do
      records = reloaded(@hidden_content)
      DataCycleCore::PreloadService.preload(records, :classification_aliases)

      ids = records.first.classification_aliases.map(&:id)

      assert_includes ids, @source_alias.id
      assert_not_includes ids, @target_alias.id, 'hidden mapping leaked into the preloaded association'
    end
  end
end

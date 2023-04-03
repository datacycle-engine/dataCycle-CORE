# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TransitiveClassificationSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @before_state = DataCycleCore.features[:transitive_classification_path][:enabled]
      DataCycleCore.features[:transitive_classification_path][:enabled] = true
      DataCycleCore::Feature::TransitiveClassificationPath.reload
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
      DataCycleCore::RunTaskJob.perform_now('db:configure:rebuild_transitive_tables')

      @tags = DataCycleCore::ClassificationTreeLabel.find_by!(name: 'Tags')
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TEST 1 ARTIKEL', tags: fetch_classification_ids(@tags.name, 'Tag 1') })

      @tree2 = DataCycleCore::ClassificationTreeLabel.create!(name: 'Tree 2')
      @tree3 = DataCycleCore::ClassificationTreeLabel.create!(name: 'Tree 3')
      @tree2.create_classification_alias('parent 1', 'mapped 1')
      @tree3.create_classification_alias('parent 2', 'mapped 2')

      tag1 = DataCycleCore::ClassificationAlias.for_tree(@tags.name).find_by!(internal_name: 'Tag 1')
      mapped1 = DataCycleCore::ClassificationAlias.for_tree(@tree2.name).find_by!(internal_name: 'mapped 1')
      mapped2 = DataCycleCore::ClassificationAlias.for_tree(@tree3.name).find_by!(internal_name: 'mapped 2')
      parent1 = DataCycleCore::ClassificationAlias.for_tree(@tree2.name).find_by!(internal_name: 'parent 1')

      mapped1.update(classification_ids: [mapped1.primary_classification.id, tag1.primary_classification.id])
      mapped2.update(classification_ids: [mapped2.primary_classification.id, parent1.primary_classification.id])
    end

    after(:all) do
      DataCycleCore.features[:transitive_classification_path][:enabled] = @before_state
      DataCycleCore::Feature::TransitiveClassificationPath.reload
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
      DataCycleCore::RunTaskJob.perform_now('db:configure:rebuild_transitive_tables')
    end

    test 'filter contents based on mapped (2 hops) classifications by id' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(fetch_classification_alias_ids(@tree3.name, 'mapped 2'))

      assert_equal(1, items.count)
    end

    test 'filter contents based on mapped (1 hop) classifications by id' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(fetch_classification_alias_ids(@tree2.name, 'mapped 1'))

      assert_equal(1, items.count)
    end

    test 'filter contents based on mapped (2 hops) classifications by id without subtree' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_without_subtree(fetch_classification_alias_ids(@tree3.name, 'mapped 2'))

      assert_equal(0, items.count)
    end

    test 'filter contents based on mapped (1 hop) classifications by id without subtree' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_without_subtree(fetch_classification_alias_ids(@tree2.name, 'mapped 1'))

      assert_equal(1, items.count)
    end

    test 'filter contents based on mapped (2 hops) classifications, excluding contents with target classification' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(fetch_classification_alias_ids(@tree3.name, 'mapped 2')).not_classification_alias_ids_with_subtree(fetch_classification_alias_ids(@tags.name, 'Tag 1'))

      assert_equal(0, items.count)
    end

    test 'filter contents based on target classification, excluding contents with mapped (2 hops) classifications' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(fetch_classification_alias_ids(@tags.name, 'Tag 1')).not_classification_alias_ids_with_subtree(fetch_classification_alias_ids(@tree3.name, 'mapped 2'))

      assert_equal(0, items.count)
    end

    test 'filter contents based on mapped (1 hop) parent classifications by id' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(fetch_classification_alias_ids(@tree2.name, 'parent 1'))

      assert_equal(1, items.count)
    end

    test 'filter contents based on mapped (2 hops) parent classifications by id' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(fetch_classification_alias_ids(@tree3.name, 'parent 2'))

      assert_equal(1, items.count)
    end

    private

    def fetch_classification_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(tree_name, alias_names)
    end

    def fetch_classification_alias_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_internal_name(alias_names).pluck(:id)
    end
  end
end

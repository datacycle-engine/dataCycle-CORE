# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TransitiveClassificationSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @before_state = DataCycleCore.transitive_classification_paths
      DataCycleCore.transitive_classification_paths = true
      DataCycleCore::ClassificationService.update_transitive_trigger_status
      DataCycleCore::RunTaskJob.set(queue: 'default').perform_now('db:configure:rebuild_ccc_relations')
      @tags = DataCycleCore::ClassificationTreeLabel.find_by!(name: 'Tags')
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TEST 1 ARTIKEL', tags: fetch_classification_ids(@tags.name, 'Tag 1') })

      @tree_2 = DataCycleCore::ClassificationTreeLabel.create!(name: 'Tree 2')
      @tree_3 = DataCycleCore::ClassificationTreeLabel.create!(name: 'Tree 3')
      @tree_2.create_classification_alias('mapped 1')
      @tree_3.create_classification_alias('mapped 2')

      tag_1 = DataCycleCore::ClassificationAlias.for_tree(@tags.name).find_by!(internal_name: 'Tag 1')
      mapped_1 = DataCycleCore::ClassificationAlias.for_tree(@tree_2.name).find_by!(internal_name: 'mapped 1')
      mapped_2 = DataCycleCore::ClassificationAlias.for_tree(@tree_3.name).find_by!(internal_name: 'mapped 2')

      mapped_1.update(classification_ids: [mapped_1.primary_classification.id, tag_1.primary_classification.id])
      mapped_2.update(classification_ids: [mapped_2.primary_classification.id, mapped_1.primary_classification.id])
    end

    after(:all) do
      DataCycleCore.transitive_classification_paths = @before_state
      DataCycleCore::ClassificationService.update_transitive_trigger_status
      DataCycleCore::RunTaskJob.set(queue: 'default').perform_now('db:configure:rebuild_ccc_relations')
    end

    test 'filter contents based on indirectly assigned classifications by id' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_without_subtree(fetch_classification_alias_ids(@tree_3.name, 'mapped 2'))

      binding.pry

      assert_equal(1, items.count)

      # items = DataCycleCore::Filter::Search.new(:de)
      #   .classification_alias_ids_without_subtree(fetch_classification_alias_ids('Tags', 'Tag 2'))
      # assert_equal(3, items.count)
    end

    private

    def fetch_classification_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(tree_name, alias_names)
    end

    def fetch_classification_alias_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_internal_name(alias_names).pluck(:id)
    end

    # test 'filter contents based on classification hierarchy by id' do
    #   items = DataCycleCore::Filter::Search.new(:de)
    #     .classification_alias_ids_with_subtree(fetch_classification_alias_ids('Tags', 'Tag 3'))
    #   assert_equal(3, items.count)

    #   # same_as
    #   # TODO: refactor to use search ?
    #   items = DataCycleCore::Thing
    #     .with_classification_alias_ids(fetch_classification_alias_ids('Tags', 'Tag 3'))
    #   assert_equal(3, items.count)
    # end

    # test 'filter contents based on classifications by name' do
    #   items = DataCycleCore::Filter::Search.new(:de)
    #     .with_classification_aliases_and_treename({ 'treeLabel' => 'Tags', 'aliases' => ['Tag 3'] })
    #   assert_equal(3, items.count)
    # end

    # test 'filter contents by excluding classifications by id' do
    #   items = DataCycleCore::Filter::Search.new(:de)
    #     .not_classification_alias_ids_with_subtree(fetch_classification_alias_ids('Tags', 'Tag 2'))
    #   assert_equal(5, items.count)
    # end

    # test 'filter contents after updating classifications' do
    #   article1 = create_content('Artikel', { name: 'ARTICLE 1', tags: fetch_classification_ids('Tags', ['Tag 1']) })
    #   article2 = create_content('Artikel', { name: 'ARTICLE 2', tags: fetch_classification_ids('Tags', ['Tag 1', 'Tag 2']) })
    #   article3 = create_content('Artikel', { name: 'ARTICLE 3', tags: fetch_classification_ids('Tags', ['Tag 1', 'Tag 3']) })

    #   items = DataCycleCore::Filter::Search.new(:de)
    #     .with_classification_aliases_and_treename({ 'treeLabel' => 'Tags', 'aliases' => ['Tag 1'] })
    #   assert_equal(3, items.count)

    #   update_content_partially(article1, { tags: [] })
    #   update_content_partially(article2, { tags: fetch_classification_ids('Tags', ['Tag 2']) })
    #   update_content_partially(article3, { tags: fetch_classification_ids('Tags', ['Tag 3']) })

    #   items = DataCycleCore::Filter::Search.new(:de)
    #     .with_classification_aliases_and_treename({ 'treeLabel' => 'Tags', 'aliases' => ['Tag 1'] })
    #   assert_equal(0, items.count)
    # end
  end
end

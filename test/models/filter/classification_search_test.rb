# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @things = DataCycleCore::Thing.count
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 1' })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 2' })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 3' })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 4' })
      create_content('Artikel', { name: 'HEADLINE 1', tags: fetch_classification_ids('Tags', ['Tag 3']) })
      create_content('Artikel', { name: 'HEADLINE 2', tags: fetch_classification_ids('Tags', ['Tag 2', 'Nested Tag 1']) })
      create_content('Artikel', { name: 'HEADLINE 3', tags: fetch_classification_ids('Tags', ['Tag 2', 'Tag 3']) })
      create_content('Artikel', { name: 'HEADLINE 4', tags: fetch_classification_ids('Tags', ['Tag 2']) })
    end

    test 'filter contents based on directly assigned classifications by id' do
      items = DataCycleCore::Filter::Search.new(locale: :de)
        .classification_alias_ids_without_subtree(fetch_classification_alias_ids('Tags', 'Tag 3'))
      assert_equal(2, items.count)

      items = DataCycleCore::Filter::Search.new(locale: :de)
        .classification_alias_ids_without_subtree(fetch_classification_alias_ids('Tags', 'Tag 2'))
      assert_equal(3, items.count)
    end

    test 'filter contents based on classification hierarchy by id' do
      items = DataCycleCore::Filter::Search.new(locale: :de)
        .classification_alias_ids_with_subtree(fetch_classification_alias_ids('Tags', 'Tag 3'))
      assert_equal(3, items.count)

      # same_as
      # TODO: refactor to use search ?
      items = DataCycleCore::Thing
        .with_classification_alias_ids(fetch_classification_alias_ids('Tags', 'Tag 3'))
      assert_equal(3, items.count)
    end

    test 'filter contents based on classifications by name' do
      items = DataCycleCore::Filter::Search.new(locale: :de)
        .with_classification_aliases_and_treename({ 'treeLabel' => 'Tags', 'aliases' => ['Tag 3'] })
      assert_equal(3, items.count)
    end

    test 'filter contents by excluding classifications by id' do
      items = DataCycleCore::Filter::Search.new(locale: :de)
        .not_classification_alias_ids_with_subtree(fetch_classification_alias_ids('Tags', 'Tag 2'))
      assert_equal(5, items.count)
    end

    test 'filter contents after updating classifications' do
      article1 = create_content('Artikel', { name: 'ARTICLE 1', tags: fetch_classification_ids('Tags', ['Tag 1']) })
      article2 = create_content('Artikel', { name: 'ARTICLE 2', tags: fetch_classification_ids('Tags', ['Tag 1', 'Tag 2']) })
      article3 = create_content('Artikel', { name: 'ARTICLE 3', tags: fetch_classification_ids('Tags', ['Tag 1', 'Tag 3']) })

      items = DataCycleCore::Filter::Search.new(locale: :de)
        .with_classification_aliases_and_treename({ 'treeLabel' => 'Tags', 'aliases' => ['Tag 1'] })
      assert_equal(3, items.count)

      update_content_partially(article1, { tags: [] })
      update_content_partially(article2, { tags: fetch_classification_ids('Tags', ['Tag 2']) })
      update_content_partially(article3, { tags: fetch_classification_ids('Tags', ['Tag 3']) })

      items = DataCycleCore::Filter::Search.new(locale: :de)
        .with_classification_aliases_and_treename({ 'treeLabel' => 'Tags', 'aliases' => ['Tag 1'] })
      assert_equal(0, items.count)
    end

    private

    def create_content(template_name, data = {})
      DataCycleCore::TestPreparations.create_content(template_name:, data_hash: data)
    end

    def update_content_partially(content, data = {})
      content.set_data_hash(partial_update: true, prevent_history: true, data_hash: data)
    end

    def fetch_classification_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names)
        .map(&:classifications).flatten.map(&:id)
    end

    def fetch_classification_alias_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).pluck(:id)
    end
  end
end

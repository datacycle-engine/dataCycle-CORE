# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ThingSearchTest < ActiveSupport::TestCase
    def setup
      create_content('Artikel', { name: 'HEADLINE 1', tags: get_classification_ids_from_alias_names('Tags', ['Tag 1']) })
      create_content('Artikel', { name: 'HEADLINE 2', tags: get_classification_ids_from_alias_names('Tags', ['Tag 2', 'Nested Tag 1']) })
      create_content('Artikel', { name: 'HEADLINE 3', tags: get_classification_ids_from_alias_names('Tags', ['Tag 1', 'Tag 2']) })
    end

    test 'test search utility functions' do
      search_count = DataCycleCore::Search.count
      data_hash = {
        'name' => 'Caption Test',
        'description' => 'Description Test',
        'link_name' => 'Link Name Test',
        'text' => 'Full Test'
      }

      DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: data_hash)

      assert_equal(1, DataCycleCore::Search.count - search_count)
    end

    test 'filters contents based on single classification' do
      assert_equal(3, DataCycleCore::Thing.with_classification_alias_ids(find_alias_ids('Inhaltstypen', 'Artikel')).count)
    end

    test 'filters contents based on multiple classifications' do
      items = DataCycleCore::Thing
        .with_classification_alias_ids(find_alias_ids('Inhaltstypen', 'Artikel'))
        .with_classification_alias_ids(find_alias_ids('Tags', 'Tag 1', 'Tag 2'))
      assert_equal(3, items.count)

      items = DataCycleCore::Thing
        .with_classification_alias_ids(find_alias_ids('Inhaltstypen', 'Artikel'))
        .with_classification_alias_ids(find_alias_ids('Tags', 'Tag 1'))
      assert_equal(2, items.count)

      items = DataCycleCore::Thing
        .with_classification_alias_ids(find_alias_ids('Inhaltstypen', 'Artikel'))
        .with_classification_alias_ids(find_alias_ids('Tags', 'Tag 2'))
      assert_equal(2, items.count)

      items = DataCycleCore::Thing
        .with_classification_alias_ids(find_alias_ids('Inhaltstypen', 'Artikel'))
        .with_classification_alias_ids(find_alias_ids('Tags', 'Tag 1'))
        .with_classification_alias_ids(find_alias_ids('Tags', 'Tag 2'))
      assert_equal(1, items.count)
    end

    test 'filters contents based on nested classifications' do
      items = DataCycleCore::Thing
        .with_classification_alias_ids(find_alias_ids('Inhaltstypen', 'Artikel'))
        .with_classification_alias_ids(find_alias_ids('Tags', 'Nested Tag 1'))
      assert_equal(1, items.count)
    end

    private

    def create_content(template_name, data = {})
      DataCycleCore::TestPreparations.create_content(template_name: template_name, data_hash: data)
    end

    def get_classification_ids_from_alias_names(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).map(&:classifications).flatten.map(&:id)
    end

    def find_alias_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).pluck(:id)
    end
  end
end

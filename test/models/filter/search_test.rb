# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SearchTest < ActiveSupport::TestCase
    def setup
      create_content('Artikel', { name: 'HEADLINE 1', tags: get_classification_ids('Tags', ['Tag 1']) })
      create_content('Artikel', { name: 'HEADLINE 2', tags: get_classification_ids('Tags', ['Tag 2', 'Nested Tag 1']) })
      create_content('Artikel', { name: 'HEADLINE 2', tags: get_classification_ids('Tags', ['Tag 1', 'Tag 2']) })

      multiling = create_content('Artikel', { name: 'XYZ de' })
      multiling.save!
      I18n.with_locale(:en) do
        multiling.set_data_hash(data_hash: { name: 'XYZ en' }.stringify_keys)
        multiling.save!
      end
    end

    test 'find multilingual entries' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de]).fulltext_search('XYZ').count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:en]).fulltext_search('XYZ').count)
      assert_equal(2, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').count)
    end

    test 'find multilingual entries and make them unique uniqe' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').distinct_by_content_id.count)
      assert_equal(2, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').distinct_by_content_id.first.available_locales.count)
    end

    private

    def create_content(template_name, data = {})
      content = DataCycleCore::TestPreparations.data_set_object(template_name)
      content.save!

      result = content.set_data_hash(data_hash: data.stringify_keys)
      raise 'InvalidData' if result[:error].present?
      content.save!
      content
    end

    def get_classification_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).map(&:classifications).flatten.map(&:id)
    end

    def find_alias_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).pluck(:id)
    end
  end
end

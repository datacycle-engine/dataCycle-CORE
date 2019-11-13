# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmbeddedSearchTest < ActiveSupport::TestCase
    def setup
      @content = DataCycleCore::TestPreparations::create_content(template_name: 'Embedded-Entity-Search', data_hash: {
        name: 'HEADLINE 1',
        description: 'DESCRIPTION 1',
        embedded_search: [
          {
            name: 'HEADLINE Search 1',
            description: 'DESCRIPTION Search 1',
            float_one: 12.3,
            float_two: 36.8
          },
          {
            name: 'HEADLINE Search 2',
            description: 'DESCRIPTION Search 2',
            float_one: 1.3,
            float_two: 1000
          }
        ]
      })
    end

    test 'test search utility functions' do
      search_count = DataCycleCore::Search.count
      byebug

    end

    private

    def get_classification_ids_from_alias_names(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).map(&:classifications).flatten.map(&:id)
    end

    def find_alias_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).pluck(:id)
    end
  end
end

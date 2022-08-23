# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    class ContentClassificationsTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @content = DataCycleCore::TestPreparations.create_content(
          template_name: 'Artikel',
          data_hash: {
            name: 'TestArtikel',
            tags: DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 1').map(&:primary_classification_id)
          }
        )

        @classification_tree = DataCycleCore::ClassificationTreeLabel.create(name: 'MAPPED TAGS')
        @mapped_tag = @classification_tree.create_classification_alias('MAPPED TAG 1')
        @mapped_tag.classifications << DataCycleCore::ClassificationAlias.for_tree('Tags')
          .with_name('Tag 1')
          .map(&:primary_classification)
        @mapped_tag.save!
      end

      test 'it should provide assigned classifications separately' do
        assert_not_empty(@content.assigned_classification_aliases)
        assert_includes(@content.assigned_classification_aliases.map(&:name), 'Tag 1')
        assert_not_includes(@content.assigned_classification_aliases.map(&:name), 'MAPPED TAG 1')
      end

      test 'it should provide mapped classifications separately' do
        assert_not_empty(@content.mapped_classification_aliases)
        assert_includes(@content.mapped_classification_aliases.map(&:name), 'MAPPED TAG 1')
        assert_not_includes(@content.mapped_classification_aliases.map(&:name), 'Tag 1')
      end

      test 'it should provide classifications for specific classification tree' do
        assert_empty(@content.classification_aliases_for_tree(tree_name: 'Unkown Tree'))

        assert_equal(1, @content.classification_aliases_for_tree(tree_name: 'Tags').size)
        assert_includes(@content.classification_aliases_for_tree(tree_name: 'Tags').map(&:name), 'Tag 1')

        assert_equal(1, @content.classification_aliases_for_tree(tree_name: 'Inhaltstypen').size)
        assert_includes(@content.classification_aliases_for_tree(tree_name: 'Inhaltstypen').map(&:name), 'Artikel')
      end
    end
  end
end

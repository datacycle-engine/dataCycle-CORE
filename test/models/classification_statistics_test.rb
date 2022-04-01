# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  class ClassificationsStatisticsTest < ActiveSupport::TestCase
    setup do
      @classification_tree = DataCycleCore::ClassificationTreeLabel.create(name: 'CLASSIFICATIONS')
      @classification_tree.create_classification_alias('CLASSIFICATION 1')
      @classification_tree.create_classification_alias('CLASSIFICATION 2')
      @classification_tree.create_classification_alias('CLASSIFICATION 3')
      @classification_tree.create_classification_alias('CLASSIFICATION 3', 'CLASSIFICATION 3 - A')
      @classification_tree.create_classification_alias('CLASSIFICATION 3', 'CLASSIFICATION 3 - B')
      @classification_tree.create_classification_alias('CLASSIFICATION 3', 'CLASSIFICATION 3 - C')
      @classification_tree.create_classification_alias('CLASSIFICATION 3', 'CLASSIFICATION 3 - D')
      @classification_tree.create_classification_alias('CLASSIFICATION 3', 'CLASSIFICATION 3 - D', 'CLASSIFICATION 3 - D - I')
      @classification_tree.create_classification_alias('CLASSIFICATION 3', 'CLASSIFICATION 3 - D', 'CLASSIFICATION 3 - D - II')

      DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: {
          name: 'TestArtikel 1',
          tags: [
            DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 1').map(&:primary_classification_id),
            DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 2').map(&:primary_classification_id)
          ].flatten
        }
      )
      DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: {
          name: 'TestArtikel 2',
          tags: DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 3').map(&:primary_classification_id)
        }
      )
      DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: {
          name: 'TestArtikel 3',
          tags: [
            DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Nested Tag 1').map(&:primary_classification_id),
            DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Nested Tag 2').map(&:primary_classification_id)
          ].flatten
        }
      )
    end

    test 'it should provide correct descendant counts for classification trees' do
      classification_tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'CLASSIFICATIONS')

      assert_equal(9, classification_tree_label.statistics.descendant_count)
    end

    test 'it should provide correct descendant counts for classification aliases' do
      classification_aliases = DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATIONS')

      assert_equal(0, classification_aliases.with_name('CLASSIFICATION 1').first.statistics.descendant_count)
      assert_equal(6, classification_aliases.with_name('CLASSIFICATION 3').first.statistics.descendant_count)
      assert_equal(2, classification_aliases.with_name('CLASSIFICATION 3 - D').first.statistics.descendant_count)
      assert_equal(0, classification_aliases.with_name('CLASSIFICATION 3 - D - I').first.statistics.descendant_count)
    end

    test 'it should provide correct linked content counts for classification trees' do
      classification_tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')

      assert_equal(5, classification_tree_label.statistics.linked_content_count)
    end

    test 'it should provide correct linked content counts for classification aliases' do
      classification_aliases = DataCycleCore::ClassificationAlias.for_tree('Tags')

      assert_equal(1, classification_aliases.with_name('Tag 1').first.statistics.linked_content_count)
      assert_equal(1, classification_aliases.with_name('Tag 2').first.statistics.linked_content_count)
      assert_equal(3, classification_aliases.with_name('Tag 3').first.statistics.linked_content_count)
      assert_equal(1, classification_aliases.with_name('Nested Tag 1').first.statistics.linked_content_count)
      assert_equal(1, classification_aliases.with_name('Nested Tag 2').first.statistics.linked_content_count)
    end
  end
end

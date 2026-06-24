# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  class CollectedClassificationContentsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(
        template_name: 'ArticleWithDuplicateClassification',
        data_hash: {
          name: 'TestArtikel',
          tags1: DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1', 'Tag 2').pluck(:classification_id)
        }
      )
      @tag1_concept_id = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1').pick(:id)
      @tag2_concept_id = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 2').pick(:id)
      @tag1_ids = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1').pluck(:classification_id).to_set
      @tag2_ids = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 2').pluck(:classification_id).to_set
      @tag_ids = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1', 'Tag 2').pluck(:classification_id).to_set
    end

    test 'it should have the correct initial assigned tags' do
      assert_equal(@tag_ids, @content.tags1.pluck(:id).to_set)
      assert_equal([], @content.tags2.pluck(:id))
      assert_equal(
        [@tag1_concept_id, @tag2_concept_id].to_set,
        @content.collected_classification_contents.where(relation: 'tags1').pluck(:classification_alias_id).to_set
      )
      assert_equal(
        [].to_set,
        @content.collected_classification_contents.where(relation: 'tags2').pluck(:classification_alias_id).to_set
      )
    end

    test 'it should correctly set and delete multiple assigned tags' do
      @content.set_data_hash(data_hash: { tags1: [], tags2: @tag_ids.to_a })

      assert_equal([], @content.tags1.pluck(:id))
      assert_equal(@tag_ids, @content.tags2.pluck(:id).to_set)
      assert_equal(
        [].to_set,
        @content.collected_classification_contents.where(relation: 'tags1').pluck(:classification_alias_id).to_set
      )
      assert_equal(
        [@tag1_concept_id, @tag2_concept_id].to_set,
        @content.collected_classification_contents.where(relation: 'tags2').pluck(:classification_alias_id).to_set
      )

      @content.set_data_hash(data_hash: { tags1: @tag_ids.to_a, tags2: [] })

      assert_equal(@tag_ids, @content.tags1.pluck(:id).to_set)
      assert_equal([], @content.tags2.pluck(:id))
      assert_equal(
        [@tag1_concept_id, @tag2_concept_id].to_set,
        @content.collected_classification_contents.where(relation: 'tags1').pluck(:classification_alias_id).to_set
      )
      assert_equal(
        [].to_set,
        @content.collected_classification_contents.where(relation: 'tags2').pluck(:classification_alias_id).to_set
      )
    end

    test 'it should correctly set and delete single assigned tags' do
      @content.set_data_hash(data_hash: { tags1: @tag1_ids.to_a, tags2: @tag2_ids.to_a })

      assert_equal(@tag1_ids, @content.tags1.pluck(:id).to_set)
      assert_equal(@tag2_ids, @content.tags2.pluck(:id).to_set)
      assert_equal(
        [@tag1_concept_id].to_set,
        @content.collected_classification_contents.where(relation: 'tags1').pluck(:classification_alias_id).to_set
      )
      assert_equal(
        [@tag2_concept_id].to_set,
        @content.collected_classification_contents.where(relation: 'tags2').pluck(:classification_alias_id).to_set
      )

      @content.set_data_hash(data_hash: { tags1: @tag2_ids.to_a, tags2: @tag1_ids.to_a })

      assert_equal(@tag2_ids, @content.tags1.pluck(:id).to_set)
      assert_equal(@tag1_ids, @content.tags2.pluck(:id).to_set)
      assert_equal(
        [@tag2_concept_id].to_set,
        @content.collected_classification_contents.where(relation: 'tags1').pluck(:classification_alias_id).to_set
      )
      assert_equal(
        [@tag1_concept_id].to_set,
        @content.collected_classification_contents.where(relation: 'tags2').pluck(:classification_alias_id).to_set
      )
    end
  end
end

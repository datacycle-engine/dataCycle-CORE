# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationAliasMappedInvalidationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      ct1 = DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE1')
      @c1 = ct1.create_classification_alias('A')

      ct2 = DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE2')
      @c1_mapping = ct2.create_classification_alias('X')
      @c6 = ct2.create_classification_alias('Z')

      @ct3 = DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE3')
      @c7 = @ct3.create_classification_alias('Q')

      DataCycleCore::ClassificationGroup.create!(
        classification: @c1_mapping.primary_classification,
        classification_alias: @c1
      )

      @thing = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: {
          name: 'Test POI 1',
          universal_classifications: [@c1_mapping.primary_classification.id]
        }
      )
    end

    test 'mapping assigned update classification attributes' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1_mapping.update!(name: 'UPDATED NAME2')

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end

    test 'mapping assigned move classification to different tree' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1_mapping.move_after(@ct3, @c7)

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end

    test 'mapping assigned merge with other classification' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1_mapping.merge_with_children(@c6)

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end

    test 'mapping assigned delete classification' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1_mapping.destroy

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end
  end
end

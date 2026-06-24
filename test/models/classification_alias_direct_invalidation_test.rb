# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationAliasDirectInvalidationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      ct1 = DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE1')
      @c1 = ct1.create_classification_alias('A')

      @ct2 = DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE2')
      @c5 = @ct2.create_classification_alias('Y')
      @c6 = @ct2.create_classification_alias('Z')

      @thing = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: {
          name: 'Test POI 1',
          universal_classifications: [@c1.primary_classification.id]
        }
      )
    end

    test 'directly assigned update classification attributes' do
      # set thing timestamp for cache_valid_since to low datetime
      # do classification operation
      # assert timestamp

      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1.update!(name: 'UPDATED NAME2')

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end

    test 'directly assigned move classification to different tree' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1.move_after(@ct2, @c5)

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end

    test 'directly assigned merge with other classification' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1.merge_with_children(@c6)

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end

    test 'mapping assigned delete classification' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1.destroy

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end
  end
end

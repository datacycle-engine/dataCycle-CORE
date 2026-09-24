# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptMappedInvalidationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      ct1 = DataCycleCore::ConceptScheme.create!(name: 'CLASSIFICATION TREE1')
      @c1 = ct1.create_concept('A')

      ct2 = DataCycleCore::ConceptScheme.create!(name: 'CLASSIFICATION TREE2')
      @c1_mapping = ct2.create_concept('X')
      @c6 = ct2.create_concept('Z')

      @ct3 = DataCycleCore::ConceptScheme.create!(name: 'CLASSIFICATION TREE3')
      @c7 = @ct3.create_concept('Q')

      DataCycleCore::ConceptLink.create!(
        parent: @c1,
        child: @c1_mapping,
        link_type: DataCycleCore::ConceptLink::LINK_TYPE_RELATED
      )

      @thing = create_content('POI', {
        name: 'Test POI 1',
        universal_classifications: [@c1_mapping.id]
      })
    end

    test 'mapping assigned update classification attributes' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1_mapping.update!(name: 'UPDATED NAME2')
      perform_enqueued_jobs

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end

    test 'mapping assigned move classification to different tree' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1_mapping.move_after(@ct3, @c7)
      perform_enqueued_jobs

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end

    test 'mapping assigned merge with other classification' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1_mapping.merge_with_children(@c6)
      perform_enqueued_jobs

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end

    test 'mapping assigned delete classification' do
      @thing.update(cache_valid_since: 3.weeks.ago.beginning_of_day)

      assert_equal(3.weeks.ago.beginning_of_day, @thing.cache_valid_since)

      @c1_mapping.destroy
      perform_enqueued_jobs

      assert_operator @thing.reload.cache_valid_since, :>, 1.day.ago.beginning_of_day
    end
  end
end

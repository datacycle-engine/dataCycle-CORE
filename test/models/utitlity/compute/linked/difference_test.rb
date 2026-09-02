# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      # Integration test for the `Linked.difference` compute method, exercised
      # through a real template (Linked-Difference-Test) whose `difference_linked`
      # attribute is computed as `automatic_linked` minus `excluded_linked`.
      class LinkedDifferenceTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @place_a = DataCycleCore::TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: { name: 'difference place a' })
          @place_b = DataCycleCore::TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: { name: 'difference place b' })
          @place_c = DataCycleCore::TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: { name: 'difference place c' })
        end

        def create_difference_content(automatic:, excluded:)
          DataCycleCore::TestPreparations.create_content(
            template_name: 'Linked-Difference-Test',
            data_hash: {
              name: 'difference test content',
              automatic_linked: automatic,
              excluded_linked: excluded
            }
          )
        end

        test 'difference computes automatic minus excluded on save' do
          content = create_difference_content(automatic: [@place_a.id, @place_b.id, @place_c.id], excluded: [@place_b.id])

          assert_equal([@place_a.id, @place_c.id].sort, content.reload.difference_linked.pluck(:id).sort)
        end

        test 'difference ignores excluded ids that are not part of the automatic set' do
          content = create_difference_content(automatic: [@place_a.id], excluded: [@place_b.id])

          assert_equal([@place_a.id], content.reload.difference_linked.pluck(:id))
        end

        test 'difference returns the full automatic set when nothing is excluded' do
          content = create_difference_content(automatic: [@place_a.id, @place_b.id], excluded: [])

          assert_equal([@place_a.id, @place_b.id].sort, content.reload.difference_linked.pluck(:id).sort)
        end

        test 'difference is empty when the automatic set is empty' do
          content = create_difference_content(automatic: [], excluded: [@place_a.id])

          assert_empty content.reload.difference_linked.pluck(:id)
        end
      end
    end
  end
end

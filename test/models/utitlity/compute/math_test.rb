# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class MathTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Math
        end

        test 'sum adds all numeric parameter values' do
          value = subject.sum(computed_parameters: { 'a' => [1, 2], 'b' => 3, 'c' => 'ignored' })

          assert_equal(6, value)
        end

        test 'count_classifications_by_tree_label counts classifications within the tree' do
          ids = get_classification_ids('Tags', 'Tag 1', 'Tag 2')

          assert_operator(ids.size, :>, 0)

          value = subject.count_classifications_by_tree_label(
            computed_parameters: { 'tags' => ids },
            computed_definition: { 'compute' => { 'tree_label' => 'Tags' } }
          )

          assert_equal(ids.size, value)
        end

        test 'count_classifications_by_tree_label returns 0 for blank parameters' do
          value = subject.count_classifications_by_tree_label(
            computed_parameters: { 'tags' => [] },
            computed_definition: { 'compute' => { 'tree_label' => 'Tags' } }
          )

          assert_equal(0, value)
        end

        test 'min/max_attribute_value_from_linked extract the numeric extremes' do
          content = struct_double(id: nil, external_source_id: nil, translatable_property_names: [])
          definition = { 'compute' => { 'value' => [{ 'attribute' => 'numbers' }] } }
          parameters = { 'numbers' => [1.5, 3.0, 2.0] }

          min = subject.min_attribute_value_from_linked(computed_parameters: parameters, computed_definition: definition, content:, key: 'result')
          max = subject.max_attribute_value_from_linked(computed_parameters: parameters, computed_definition: definition, content:, key: 'result')

          assert_in_delta(1.5, min)
          assert_in_delta(3.0, max)
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class ComputedTest < ActiveSupport::TestCase
        test 'Testing Utility::Calculation::Math methods' do
          data_set = DataCycleCore::TestPreparations.data_set_object('creative_works', 'Calculation-Math')
          data_set.save

          data = {
            'value_1' => 5,
            'value_2' => 6
          }

          data_set.set_data_hash(data_hash: data, update_search_all: false)
          data_set.save
          expected_hash = {
            'value_1' => 5,
            'value_2' => 6,
            'math_sum' => 11
          }

          assert_equal(expected_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(5, data_set.value_1)
          assert_equal(6, data_set.value_2)
          assert_equal(11, data_set.math_sum)

          assert_equal(1, DataCycleCore::CreativeWork.where(template: false, template_name: 'Calculation-Math').count)
        end

        test 'Testing Utility::Calculation::Common methods' do
          data_set = DataCycleCore::TestPreparations.data_set_object('creative_works', 'Calculation-Common')
          data_set.save

          data = {
            'value_1' => 5,
            'value_2' => 6
          }

          data_set.set_data_hash(data_hash: data, update_search_all: false)
          data_set.save
          expected_hash = {
            'value_1' => 5,
            'value_2' => 6,
            'common_copy' => 5
          }
          assert_equal(expected_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(5, data_set.value_1)
          assert_equal(6, data_set.value_2)
          assert_equal(5, data_set.common_copy)

          assert_equal(1, DataCycleCore::CreativeWork.where(template: false, template_name: 'Calculation-Common').count)
        end
      end
    end
  end
end

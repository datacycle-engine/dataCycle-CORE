# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class ComputedTest < ActiveSupport::TestCase
        test 'Testing Utility::Calculation::Math methods' do
          data = {
            'value_1' => 5,
            'value_2' => 6
          }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Calculation-Math', data_hash: data)

          expected_hash = {
            'value_1' => 5,
            'value_2' => 6,
            'math_sum' => 11
          }

          assert_equal(expected_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(5, data_set.value_1)
          assert_equal(6, data_set.value_2)
          assert_equal(11, data_set.math_sum)

          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Calculation-Math').count)
        end

        test 'Testing Utility::Calculation::Common methods' do
          data = {
            'value_1' => 5,
            'value_2' => 6
          }

          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Calculation-Common', data_hash: data)
          expected_hash = {
            'value_1' => 5,
            'value_2' => 6,
            'common_copy' => 5
          }
          assert_equal(expected_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(5, data_set.value_1)
          assert_equal(6, data_set.value_2)
          assert_equal(5, data_set.common_copy)

          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Calculation-Common').count)
        end

        test 'Testing Utility::Calculation::String methods' do
          data = {
            'value_1' => 'val_1',
            'value_2' => 'val_2'
          }

          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Computed-String', data_hash: data)
          expected_hash = {
            'value_1' => 'val_1',
            'value_2' => 'val_2',
            'computed_value_correct' => "-text-de-text-#{data_set.created_at}-text-val_2"
          }

          assert_equal(expected_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal('val_1', data_set.value_1)
          assert_equal('val_2', data_set.value_2)
          assert_equal("-text-de-text-#{data_set.created_at}-text-val_2", data_set.computed_value_correct)
          assert_nil(data_set.computed_value_incorrect)

          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Computed-String').count)

          I18n.with_locale(:en) do
            data_set.set_data_hash(
              data_hash: data,
              prevent_history: true
            )

            expected_hash = {
              'value_1' => 'val_1',
              'value_2' => 'val_2',
              'computed_value_correct' => "-text-en-text-#{data_set.created_at}-text-val_2"
            }

            assert_equal(expected_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))
            assert_equal('val_1', data_set.value_1)
            assert_equal('val_2', data_set.value_2)
            assert_equal("-text-en-text-#{data_set.created_at}-text-val_2", data_set.computed_value_correct)

            assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Computed-String').count)
          end
        end
      end
    end
  end
end

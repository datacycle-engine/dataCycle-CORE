# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Base
        class ValuePresent < DataCycleCore::TestCases::ActiveSupportTestCase
          test 'value_present? works with normal keys' do
            key = 'image'
            assert_equal false, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => [] }, key)
            assert_equal false, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => {} }, key)
            assert_equal false, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => [{}, {}] }, key)

            assert_equal true, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => ['uuid'] }, key)
            assert_equal true, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => { 'name' => 'test' } }, key)
            assert_equal true, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => [{ 'name' => 'haha' }] }, key)
          end

          test 'value_present? works with nested keys' do
            key = 'image.name'
            assert_equal false, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => [] }, key)
            assert_equal false, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => [{}, {}] }, key)
            assert_equal false, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => ['uuid'] }, key)
            assert_equal false, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => [{ 'not_name' => 'test' }] }, key)

            assert_equal true, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => [{ 'name' => 'haha' }] }, key)
            assert_equal true, DataCycleCore::Utility::ContentScore::Base.value_present?({ 'image' => { 'name' => 'haha' } }, key)
          end
        end
      end
    end
  end
end

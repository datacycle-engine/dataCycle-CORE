# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Base
        class ValuesPresent < DataCycleCore::TestCases::ActiveSupportTestCase
          test 'values_present works with normal keys' do
            keys = ['image']
            assert_equal [0, 1], DataCycleCore::Utility::ContentScore::Base.values_present({ 'image' => [] }, keys)
            assert_equal [1, 1], DataCycleCore::Utility::ContentScore::Base.values_present({ 'image' => ['uuid'] }, keys)

            keys = ['image', 'name']
            assert_equal [0, 2], DataCycleCore::Utility::ContentScore::Base.values_present({ 'image' => [] }, keys)
            assert_equal [1, 2], DataCycleCore::Utility::ContentScore::Base.values_present({ 'image' => ['uuid'] }, keys)
            assert_equal [2, 2], DataCycleCore::Utility::ContentScore::Base.values_present({ 'image' => ['uuid'], 'name' => 'test' }, keys)
          end

          test 'values_present works with nested keys' do
            keys = ['image.name']
            assert_equal [0, 1], DataCycleCore::Utility::ContentScore::Base.values_present({ 'image' => [] }, keys)
            assert_equal [0, 1], DataCycleCore::Utility::ContentScore::Base.values_present({ 'image' => ['test'] }, keys)
            assert_equal [1, 1], DataCycleCore::Utility::ContentScore::Base.values_present({ 'image' => [{ 'name' => 'test' }] }, keys)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module String
        class ByQuantity < DataCycleCore::TestCases::ActiveSupportTestCase
          test 'by_quantity works with strings' do
            definition = { 'content_score' => { 'score_matrix' => { 'min' => 1 } } }
            key = 'name'

            assert_equal 0, DataCycleCore::Utility::ContentScore::Common.by_quantity(definition: definition, key: key, data_hash: { 'name' => nil })
            assert_equal 0, DataCycleCore::Utility::ContentScore::Common.by_quantity(definition: definition, key: key, data_hash: { 'name' => '' })
            assert_equal 1, DataCycleCore::Utility::ContentScore::Common.by_quantity(definition: definition, key: key, data_hash: { 'name' => 't' })
            assert_equal 1, DataCycleCore::Utility::ContentScore::Common.by_quantity(definition: definition, key: key, data_hash: { 'name' => 'test' })
          end
        end
      end
    end
  end
end

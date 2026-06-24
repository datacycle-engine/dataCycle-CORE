# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      module Common
        class ByPresence < DataCycleCore::TestCases::ActiveSupportTestCase
          test 'by_presence works with multiple types' do
            key = 'name'

            assert_equal 0, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: {})
            assert_equal 0, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: { 'name' => nil })
            assert_equal 0, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: { 'name' => '' })
            assert_equal 0, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: { 'name' => [] })
            assert_equal 0, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: { 'name' => {} })
            assert_equal 1, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: { 'name' => 't' })
            assert_equal 1, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: { 'name' => 'test' })
            assert_equal 1, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: { 'name' => 0 })
            assert_equal 1, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: { 'name' => 1.6 })
            assert_equal 1, DataCycleCore::Utility::ContentScore::Common.by_presence(key:, parameters: { 'name' => Time.zone.now })
          end
        end
      end
    end
  end
end

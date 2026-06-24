# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Type
    module Thing
      class StringTest < DataCycleCore::TestCases::ActiveSupportTestCase
        test 'casts blank values through the default string type' do
          type = DataCycleCore::Type::Thing::String.new

          assert_equal '', type.cast('')
          assert_nil type.cast(nil)
        end

        test 'normalizes non-blank values via the data converter' do
          type = DataCycleCore::Type::Thing::String.new

          assert_equal 'hello world', type.cast('hello world')
        end
      end
    end
  end
end

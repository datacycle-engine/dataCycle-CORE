# frozen_string_literal: true

require 'test_helper'
require 'rake_helpers/time_helper'

module DataCycleCore
  class TimeHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'format_time pads integer part and fills decimal part' do
      assert_equal '    1.235 s', TimeHelper.format_time(1.23456, 5, 3, 's')
    end

    test 'format_time fills missing decimals with zeros' do
      assert_equal ' 5.000 ms', TimeHelper.format_time(5.0, 2, 3, 'ms')
    end
  end
end

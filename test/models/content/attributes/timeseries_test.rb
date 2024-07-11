# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    module Attributes
      class TimeseriesTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Series 1' })
        end

        test 'write timeseries with set_data_hash' do
          two_minute_ago = 2.minutes.ago
          one_minute_ago = 1.minute.ago

          @content.set_data_hash(data_hash: { series: [
                                   { timestamp: two_minute_ago, value: 1 },
                                   { timestamp: one_minute_ago, value: 2 }
                                 ] })

          assert_equal 2, @content.series.count

          @content.set_data_hash(data_hash: { series: [
                                   { timestamp: two_minute_ago, value: 1 },
                                   { timestamp: one_minute_ago, value: 2 },
                                   { timestamp: Time.zone.now, value: 3 }
                                 ] })

          assert_equal 3, @content.series.count
        end
      end
    end
  end
end

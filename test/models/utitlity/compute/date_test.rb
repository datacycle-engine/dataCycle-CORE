# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class DateTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Date
        end

        test 'latest_timestamp_from_timeseries returns the latest timestamp from the parameter values' do
          older = 2.days.ago.change(usec: 0)
          newer = 1.hour.ago.change(usec: 0)

          value = subject.latest_timestamp_from_timeseries(
            computed_parameters: {
              'series' => [{ 'timestamp' => older }, { 'timestamp' => newer }]
            },
            content: nil
          )

          assert_equal(newer.in_time_zone, value)
        end

        test 'latest_timestamp_from_timeseries falls back to the content timeseries when parameters are empty' do
          latest = 30.minutes.ago.change(usec: 0)
          content = struct_double(measurements: [struct_double(timestamp: latest)])

          value = subject.latest_timestamp_from_timeseries(
            computed_parameters: { 'measurements' => [] },
            content:
          )

          assert_equal(latest.in_time_zone, value)
        end
      end
    end
  end
end

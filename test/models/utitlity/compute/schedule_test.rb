# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class ScheduleTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @start_time = Time.zone.local(2025, 6, 15, 9, 0, 0)
          @end_time = @start_time + 2.hours
          schedule_hash = DataCycleCore::Schedule.transform_data_for_data_hash({
            start_time: { time: @start_time, zone: @start_time.time_zone.name },
            end_time: { time: @end_time, zone: @end_time.time_zone.name },
            rrules: [{ rule_type: 'IceCube::SingleOccurrenceRule' }],
            rtimes: nil,
            extimes: nil
          }.with_indifferent_access)
          @parameters = { 'event_schedule' => [schedule_hash] }
        end

        def subject
          DataCycleCore::Utility::Compute::Schedule
        end

        test 'start_date returns the earliest schedule start' do
          assert_equal(@start_time, subject.start_date(computed_parameters: @parameters))
        end

        test 'end_date returns the latest schedule end' do
          assert_equal(@end_time, subject.end_date(computed_parameters: @parameters))
        end

        test 'start_date_only_date returns the start as a date' do
          assert_equal(@start_time.to_date, subject.start_date_only_date(computed_parameters: @parameters))
        end

        test 'end_date_only_date returns the end as a date' do
          assert_equal(@end_time.to_date, subject.end_date_only_date(computed_parameters: @parameters))
        end
      end
    end
  end
end

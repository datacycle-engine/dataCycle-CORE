# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Attributes
        class ScheduleTest < DataCycleCore::V4::Base
          test 'api/v4/things schedule attribute with valid schedule' do # rubocop:disable Minitest/MultipleAssertions
            @event_a = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            schedule_a = DataCycleCore::TestPreparations.generate_schedule(8.days.ago.midday, 5.days.ago, 1.hour).serialize_schedule_object
            @event_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_a.schedule_object.to_hash] })

            post api_v4_thing_path(id: @event_a.id), params: { include: 'eventSchedule', fields: 'eventSchedule' }
            json_data = response.parsed_body
            schedule = json_data.dig('@graph', 0, 'eventSchedule', 0)

            assert schedule.key?('startDate')
            assert schedule.key?('endDate')
            assert schedule.key?('startTime')
            assert schedule.key?('endTime')
            assert schedule.key?('duration')
            assert schedule.key?('repeatFrequency')
            assert schedule.key?('scheduleTimezone')

            assert_equal 8.days.ago.midday.to_date.iso8601, schedule['startDate']
            assert_equal 5.days.ago.to_date.iso8601, schedule['endDate']
            assert_equal 8.days.ago.midday.to_s(:only_time), schedule['startTime']
            assert_equal (8.days.ago.midday + 1.hour).to_s(:only_time), schedule['endTime']
            assert_equal 1.hour.iso8601, schedule['duration']
            assert_equal 'P1D', schedule['repeatFrequency']
            assert_equal 'Europe/Vienna', schedule['scheduleTimezone']
          end

          test 'api/v4/things schedule attribute with schedule without occurrences' do # rubocop:disable Minitest/MultipleAssertions
            @event_b = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            schedule_b = DataCycleCore::TestPreparations.generate_schedule('2023-05-25T15:00'.in_time_zone, '2023-05-30'.in_time_zone, 1.5.hours, frequency: 'weekly', week_days: [3]).serialize_schedule_object
            @event_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_b.schedule_object.to_hash] })

            post api_v4_thing_path(id: @event_b.id), params: { include: 'eventSchedule', fields: 'eventSchedule' }
            json_data = response.parsed_body
            schedule = json_data.dig('@graph', 0, 'eventSchedule', 0)

            assert schedule.key?('startDate')
            assert schedule.key?('endDate')
            assert schedule.key?('startTime')
            assert schedule.key?('endTime')
            assert schedule.key?('duration')
            assert schedule.key?('repeatFrequency')
            assert schedule.key?('scheduleTimezone')

            assert_equal '2023-05-25', schedule['startDate']
            assert_equal '2023-05-30', schedule['endDate']
            assert_equal '15:00', schedule['startTime']
            assert_equal '16:30', schedule['endTime']
            assert_equal 'PT1H30M', schedule['duration']
            assert_equal 'P1W', schedule['repeatFrequency']
            assert_equal 'Europe/Vienna', schedule['scheduleTimezone']
          end

          test 'api/v4/things schedule attribute with schedule without duration' do # rubocop:disable Minitest/MultipleAssertions
            event = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            event_schedule = DataCycleCore::TestPreparations.generate_schedule('2023-05-25T15:00'.in_time_zone, '2023-05-30'.in_time_zone, nil, frequency: 'weekly', week_days: [5]).serialize_schedule_object
            event.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [event_schedule.schedule_object.to_hash] })

            post api_v4_thing_path(id: event.id), params: { include: 'eventSchedule', fields: 'eventSchedule' }
            json_data = response.parsed_body
            schedule = json_data.dig('@graph', 0, 'eventSchedule', 0)

            assert schedule.key?('startDate')
            assert schedule.key?('endDate')
            assert schedule.key?('startTime')
            assert schedule.key?('endTime')
            assert schedule.key?('repeatFrequency')
            assert schedule.key?('scheduleTimezone')

            assert_equal '2023-05-25', schedule['startDate']
            assert_equal '2023-05-26', schedule['endDate']
            assert_equal '15:00', schedule['startTime']
            assert_equal '15:00', schedule['endTime']
            assert_equal 'P1W', schedule['repeatFrequency']
            assert_equal 'Europe/Vienna', schedule['scheduleTimezone']
          end

          test 'api/v4/things schedule attribute with schedule with single occurrence' do # rubocop:disable Minitest/MultipleAssertions
            event = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            event_schedule = DataCycleCore::TestPreparations.generate_schedule('2023-05-25T15:00'.in_time_zone, '2023-05-25'.in_time_zone, 2.hours, frequency: nil).serialize_schedule_object
            event.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [event_schedule.schedule_object.to_hash] })

            post api_v4_thing_path(id: event.id), params: { include: 'eventSchedule', fields: 'eventSchedule' }
            json_data = response.parsed_body
            schedule = json_data.dig('@graph', 0, 'eventSchedule', 0)

            assert schedule.key?('startDate')
            assert schedule.key?('endDate')
            assert schedule.key?('startTime')
            assert schedule.key?('endTime')
            assert schedule.key?('scheduleTimezone')

            assert_equal '2023-05-25', schedule['startDate']
            assert_equal '2023-05-25', schedule['endDate']
            assert_equal '15:00', schedule['startTime']
            assert_equal '17:00', schedule['endTime']
            assert_equal 'Europe/Vienna', schedule['scheduleTimezone']
          end
        end
      end
    end
  end
end

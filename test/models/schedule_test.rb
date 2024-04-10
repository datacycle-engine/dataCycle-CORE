# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ScheduleTest < DataCycleCore::TestCases::ActiveSupportTestCase
    setup do
      @schedule = DataCycleCore::Schedule.new
      @dtstart = Time.parse('2019-11-20T9:00').in_time_zone
      duration = 7.hours
      @dtend = Time.parse('2020-01-04T16:00').in_time_zone
      end_time = @dtstart + duration
      @schedule.schedule_object = IceCube::Schedule.new(@dtstart, end_time:) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9).until(@dtend))
      end
      @schedule.serialize_schedule_object
    end

    def create_schedule(dtstart, dtend, duration)
      schedule = DataCycleCore::Schedule.new
      dtstart = dtstart
      dtend = dtend
      schedule.schedule_object = IceCube::Schedule.new(dtstart, { duration: duration.to_i }) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(dtstart.hour).until(dtend))
      end
      schedule
    end

    test 'serialize to hash and self apply --> unchanged' do
      schedule_hash = @schedule.to_h
      @schedule.from_hash(schedule_hash)
      assert(schedule_hash == @schedule.to_h)
    end

    test 'serialize to hash, create from hash' do
      schedule_hash = @schedule.to_h
      [:start_time, :end_time, :rrules, :rtimes, :extimes, :dtstart, :dtend].each do |key|
        assert(schedule_hash.key?(key))
      end
      schedule2 = DataCycleCore::Schedule.new.from_hash(schedule_hash)
      assert(schedule_hash == schedule2.to_h)
    end

    test 'save schedule, make sure all table columns are correctly filled' do
      schedule = DataCycleCore::Schedule.new
      dtstart = Time.parse('2019-11-20T9:00').in_time_zone
      dtend = Time.parse('2020-01-04T16:00').in_time_zone
      rrule = IceCube::Rule.daily.hour_of_day(9).until(dtend)
      duration = 7.hours
      schedule.schedule_object = IceCube::Schedule.new(dtstart, { duration: duration.to_i }) do |s|
        s.add_recurrence_rule(rrule)
      end

      assert_equal(dtstart, schedule.dtstart)
      assert_equal(dtend, schedule.dtend)
      assert_equal(duration, schedule.duration)
      assert_equal(rrule.to_ical, schedule.rrule)
      assert_nil(schedule.id)

      [:rdate, :exdate].each do |attribute|
        assert_equal([], schedule.send(attribute))
      end

      schedule.save
      assert(schedule.id.present?)
      assert_equal(dtstart, schedule.dtstart)
      assert_equal(dtend, schedule.dtend)
    end

    test 'handling of start/end dates and times in combination with duration' do
      dtstart = Time.parse('2019-11-20T9:00').in_time_zone
      dtend = Time.parse('2020-01-04T16:00').in_time_zone
      duration = 7.hours
      schedule = create_schedule(dtstart, dtend, duration)
      schedule.save
      assert_equal(dtstart, schedule.dtstart)
      assert_equal(dtend, schedule.dtend)
      assert_equal(duration, schedule.duration)
      expected_serialization = {
        '@context' => 'https://schema.org/',
        '@type' => 'Schedule',
        '@id' => schedule.id,
        'inLanguage' => 'de',
        'startDate' => '2019-11-20',
        'endDate' => '2020-01-04',
        'startTime' => '09:00',
        'endTime' => '16:00',
        'duration' => 'PT7H',
        'repeatFrequency' => 'P1D',
        'scheduleTimezone' => 'Europe/Vienna'
      }
      assert_equal(expected_serialization, schedule.to_schedule_schema_org.except('identifier'))
    end

    test 'handling start/end date with only starttime and duration given' do
      dtstart = Time.parse('2019-11-20T9:00').in_time_zone
      dtend = Time.parse('2020-01-03T16:00').in_time_zone
      duration = 7.hours
      schedule = create_schedule(dtstart, dtend, duration)
      schedule.save
      assert_equal(dtstart, schedule.dtstart)
      assert_equal(dtend, schedule.dtend)
      assert_equal(duration, schedule.duration)
      expected_serialization = {
        '@context' => 'https://schema.org/',
        '@type' => 'Schedule',
        '@id' => schedule.id,
        'inLanguage' => 'de',
        'startDate' => '2019-11-20',
        'endDate' => '2020-01-03',
        'startTime' => '09:00',
        'endTime' => '16:00',
        'duration' => 'PT7H',
        'repeatFrequency' => 'P1D',
        'scheduleTimezone' => 'Europe/Vienna'
      }
      assert_equal(expected_serialization, schedule.to_schedule_schema_org.except('identifier'))
    end

    test 'handling start date time given and duration' do
      dtstart = Time.parse('2019-11-20T9:00').in_time_zone
      duration = 7.hours
      schedule = create_schedule(dtstart, nil, duration)
      schedule.save
      assert_equal(dtstart, schedule.dtstart)
      assert_nil(schedule.dtend)
      assert_equal(duration, schedule.duration)
      expected_serialization = {
        '@context' => 'https://schema.org/',
        '@type' => 'Schedule',
        '@id' => schedule.id,
        'inLanguage' => 'de',
        'startDate' => '2019-11-20',
        'startTime' => '09:00',
        'duration' => 'PT7H',
        'repeatFrequency' => 'P1D',
        'scheduleTimezone' => 'Europe/Vienna'
      }
      assert_equal(expected_serialization, schedule.to_schedule_schema_org.except('identifier'))
    end

    test 'handling long non recurring schedule with end_time' do
      dtstart = Time.parse('2019-11-20T9:00').in_time_zone
      dtend = Time.parse('2020-01-03T16:00').in_time_zone

      schedule = DataCycleCore::Schedule.new
      schedule.schedule_object = IceCube::Schedule.new(dtstart, { end_time: dtend })
      schedule.save
      assert_equal(dtstart, schedule.dtstart)
      assert_equal(dtend, schedule.dtend)
      expected_serialization = {
        '@context' => 'https://schema.org/',
        '@type' => 'Schedule',
        '@id' => schedule.id,
        'inLanguage' => 'de',
        'startDate' => '2019-11-20',
        'startTime' => '09:00',
        'endDate' => '2020-01-03',
        'endTime' => '16:00',
        'duration' => 'P1M14DT7H',
        'scheduleTimezone' => 'Europe/Vienna'
      }
      assert_equal(expected_serialization, schedule.to_schedule_schema_org.except('identifier'))
    end

    test 'handling long non recurring schedule with duration' do
      dtstart = Time.parse('2019-11-20T9:00').in_time_zone
      dtend = Time.parse('2020-01-03T16:00').in_time_zone

      schedule = DataCycleCore::Schedule.new
      schedule.schedule_object = IceCube::Schedule.new(dtstart, { duration: (dtend - dtstart).to_i })
      schedule.save
      assert_equal(dtstart, schedule.dtstart)
      assert_equal(dtend, schedule.dtend)
      expected_serialization = {
        '@context' => 'https://schema.org/',
        '@type' => 'Schedule',
        '@id' => schedule.id,
        'inLanguage' => 'de',
        'startDate' => '2019-11-20',
        'startTime' => '09:00',
        'endDate' => '2020-01-03',
        'endTime' => '16:00',
        'duration' => 'P1M14DT7H',
        'scheduleTimezone' => 'Europe/Vienna'
      }
      assert_equal(expected_serialization, schedule.to_schedule_schema_org.except('identifier'))
    end
  end
end

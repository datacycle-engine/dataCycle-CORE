# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ScheduleTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
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
      schedule.schedule_object = IceCube::Schedule.new(dtstart, { duration: duration.to_i }) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(dtstart.hour).until(dtend))
      end
      schedule
    end

    # builds an unsaved schedule wrapping an in-memory IceCube schedule (no DB round-trip)
    def schedule_with_rule(rule, dtstart: @dtstart, duration: nil)
      schedule = DataCycleCore::Schedule.new
      options = duration ? { duration: duration.to_i } : {}
      schedule.schedule_object = IceCube::Schedule.new(dtstart, options) do |s|
        s.add_recurrence_rule(rule)
      end
      schedule
    end

    test 'serialize to hash and self apply --> unchanged' do
      schedule_hash = @schedule.to_h
      @schedule.from_hash(schedule_hash)

      assert_equal(schedule_hash, @schedule.to_h)
    end

    test 'serialize to hash, create from hash' do
      schedule_hash = @schedule.to_h

      [:start_time, :end_time, :rrules, :rtimes, :extimes, :dtstart, :dtend].each do |key|
        assert(schedule_hash.key?(key))
      end
      schedule2 = DataCycleCore::Schedule.new.from_hash(schedule_hash)

      assert_equal(schedule_hash, schedule2.to_h)
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

      assert_predicate(schedule.id, :present?)
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

    # ---------------------------------------------------------------------------
    # serializers / accessors (in-memory, no persistence)
    # ---------------------------------------------------------------------------

    test 'to_s renders schedule with start/end window' do
      schedule = create_schedule(@dtstart, @dtend, 7.hours)

      assert_kind_of(String, schedule.to_s)
      assert_includes(schedule.to_s, '2019-11-20')
    end

    test 'to_repeat_frequency maps yearly and monthly rules' do
      assert_equal('P1Y', @schedule.to_repeat_frequency({ interval: 1, rule_type: 'IceCube::YearlyRule' }))
      assert_equal('P2M', @schedule.to_repeat_frequency({ interval: 2, rule_type: 'IceCube::MonthlyRule' }))
      assert_nil(@schedule.to_repeat_frequency({ interval: nil, rule_type: nil }))
    end

    test 'to_schedule_schema_org serializes monthly day_of_week rule' do
      schedule = schedule_with_rule(IceCube::Rule.monthly.day_of_week(monday: [1]).until(@dtend))
      result = schedule.to_schedule_schema_org

      assert_equal('https://schema.org/Monday', result['byDay'])
      assert_equal(1, result['byMonthWeek'])
    end

    test 'to_schedule_schema_org_api_v3 serializes terminating weekly rule' do
      schedule = schedule_with_rule(IceCube::Rule.weekly.day(:monday, :wednesday).until(@dtend))
      result = schedule.to_schedule_schema_org_api_v3

      assert_equal('Schedule', result['@type'])
      assert_equal('EventSchedule', result['contentType'])
      assert_includes(result['byDay'], 'https://schema.org/Monday')
      assert_predicate(result['identifier'], :present?)
    end

    test 'to_schedule_schema_org_api_v2 serializes terminating weekly rule' do
      schedule = schedule_with_rule(IceCube::Rule.weekly.day(:monday, :wednesday).until(@dtend))
      result = schedule.to_schedule_schema_org_api_v2

      assert_equal('EventSchedule', result['contentType'])
      assert_includes(result['by_day'], 'https://schema.org/Monday')
    end

    test 'to_ical_string_api_v4 returns ical payload' do
      schedule = schedule_with_rule(IceCube::Rule.daily.until(@dtend))
      result = schedule.to_ical_string_api_v4

      assert_predicate(result['dc:ical'], :present?)
    end

    test 'to_event_dates for terminating, non-terminating and blank schedules' do
      terminating = schedule_with_rule(IceCube::Rule.daily.until(@dtstart + 5.days))

      assert_equal(6, terminating.to_event_dates.size)

      non_terminating = schedule_with_rule(IceCube::Rule.daily)

      assert_equal(10, non_terminating.to_event_dates.size)

      blank = DataCycleCore::Schedule.new
      blank.schedule_object = nil

      assert_equal([], blank.to_event_dates)
    end

    test 'occurs_between? checks overlap with given range' do
      schedule = schedule_with_rule(IceCube::Rule.daily.until(@dtend))

      assert(schedule.occurs_between?(@dtstart, @dtstart + 2.days))
    end

    test 'to_opening_hours_specification_schema_org handles exception times' do
      schedule = schedule_with_rule(IceCube::Rule.daily.hour_of_day(9))
      serialized = {
        dtstart: Time.zone.parse('2020-01-01 09:00'),
        extimes: [
          { time: Time.zone.parse('2020-01-10 09:00') },
          { time: Time.zone.parse('2020-01-20 09:00') }
        ],
        rrules: [{ until: Time.zone.parse('2020-02-01 09:00'), validations: { day: [1, 2, 3] } }]
      }

      result = schedule.stub(:to_h, serialized) do
        schedule.to_opening_hours_specification_schema_org
      end

      assert_equal(3, result.size)
      assert_equal('OpeningHoursSpecification', result.first['@type'])
    end

    test 'dtend falls back to start_time for terminating rule without occurrences' do
      schedule = schedule_with_rule(IceCube::Rule.daily.count(0))

      assert_equal(schedule.schedule_object.start_time, schedule.dtend)
    end

    test 'duration is nil when schedule_object is changed to nil' do
      schedule = DataCycleCore::Schedule.new
      schedule.schedule_object = IceCube::Schedule.new(@dtstart)
      schedule.schedule_object = nil

      assert_nil(schedule.duration)
    end

    test 'load_schedule_object adds exception times' do
      schedule = DataCycleCore::Schedule.new
      schedule[:dtstart] = @dtstart
      schedule[:rdate] = []
      schedule[:exdate] = [@dtstart + 1.day]
      object = schedule.send(:load_schedule_object)

      assert_equal(1, object.extimes.size)
    end

    test 'from_h assigns dtstart/dtend when no recurrence keys present' do
      schedule = DataCycleCore::Schedule.new
      schedule.from_h({ dtstart: @dtstart, dtend: @dtend })

      assert_equal(@dtstart, schedule.dtstart)
      assert_equal(@dtend, schedule.dtend)
    end

    test 'first_by_external_key_or_id guards and query branches' do
      assert_nil(DataCycleCore::Schedule.first_by_external_key_or_id(nil, nil))
      assert_nil(DataCycleCore::Schedule.first_by_external_key_or_id('non-existent-key', nil))
      assert_nil(DataCycleCore::Schedule.first_by_external_key_or_id(SecureRandom.uuid, nil))
    end

    # ---------------------------------------------------------------------------
    # History subclass
    # ---------------------------------------------------------------------------

    test 'history? differs between Schedule and Schedule::History' do
      assert_not(DataCycleCore::Schedule.new.history?)
      assert_predicate(DataCycleCore::Schedule::History.new, :history?)
    end

    test 'Schedule::History to_h/from_h round-trip thing_history_id' do
      history = DataCycleCore::Schedule::History.new
      history.from_h({ thing_history_id: nil, dtstart: @dtstart })

      assert(history.to_h.key?(:thing_history_id))
      assert_equal(@dtstart, history.dtstart)
    end

    # ---------------------------------------------------------------------------
    # class-level value transformations (pure, no DB)
    # ---------------------------------------------------------------------------

    test 'time_to_duration computes durations including past-midnight closing' do
      assert_equal(0, DataCycleCore::Schedule.time_to_duration(nil, '12:00'))
      assert_equal(8.hours, DataCycleCore::Schedule.time_to_duration('09:00', '17:00'))
      assert_equal(3.hours, DataCycleCore::Schedule.time_to_duration('22:00', '25:00'))
    end

    test 'duration_to_iso8601_string handles all input types' do
      assert_equal('PT7H', DataCycleCore::Schedule.duration_to_iso8601_string(7.hours))
      assert_equal('PT2H', DataCycleCore::Schedule.duration_to_iso8601_string({ hours: 2 }))
      assert_equal('PT1H', DataCycleCore::Schedule.duration_to_iso8601_string(3600))
      assert_nil(DataCycleCore::Schedule.duration_to_iso8601_string('PXYZ'))
    end

    test 'parts_to_iso8601_duration falls back to zero on parse error' do
      assert_equal(ActiveSupport::Duration.build(0), DataCycleCore::Schedule.parts_to_iso8601_duration({ unknown_part: 1 }))
    end

    test 'to_h_from_schema_org maps schema.org schedule payloads' do
      assert_nil(DataCycleCore::Schedule.to_h_from_schema_org(nil))
      assert_nil(DataCycleCore::Schedule.to_h_from_schema_org({ 'repeatFrequency' => 'P1D' }))

      weekly = DataCycleCore::Schedule.to_h_from_schema_org({
        'startDate' => '2020-01-01', 'startTime' => '09:00', 'endTime' => '17:00',
        'repeatFrequency' => 'P1W', 'byDay' => ['https://schema.org/Monday']
      })

      assert_predicate(weekly[:start_time][:time], :present?)
      assert_equal([1], weekly[:rrules][0][:validations][:day])

      monthly_day = DataCycleCore::Schedule.to_h_from_schema_org({
        'startDate' => '2020-01-01', 'startTime' => '09:00',
        'repeatFrequency' => 'P1M', 'byMonthDay' => [15]
      })

      assert_equal([15], monthly_day[:rrules][0][:validations][:day_of_month])

      monthly_week = DataCycleCore::Schedule.to_h_from_schema_org({
        'startDate' => '2020-01-01', 'startTime' => '09:00',
        'repeatFrequency' => 'P1M', 'byMonthWeek' => 1, 'byDay' => ['https://schema.org/Monday']
      })

      assert_predicate(monthly_week[:rrules][0][:validations][:day_of_week], :present?)
    end

    test 'add_missing_rrule_values! and add_missing_rrule_validations! normalize rrules' do
      data = { start_time: { time: Time.zone.parse('2020-03-15 09:30') } }

      yearly = DataCycleCore::Schedule.add_missing_rrule_values!({ rule_type: 'IceCube::YearlyRule' }, data)

      assert_equal(1, yearly[:interval])
      assert_equal([Time.zone.parse('2020-03-15 09:30').yday], yearly[:validations][:day_of_year])

      weekly = DataCycleCore::Schedule.add_missing_rrule_validations!({ rule_type: 'IceCube::WeeklyRule', validations: { day: ['3', '1'] } }, data)

      assert_equal([1, 3], weekly[:validations][:day])

      monthly_dow = DataCycleCore::Schedule.add_missing_rrule_validations!({ rule_type: 'IceCube::MonthlyRule', validations: { day_of_week: '{"1":[1]}' } }, data)

      assert_equal({ '1' => [1] }, monthly_dow[:validations][:day_of_week])

      monthly_dow_hash = DataCycleCore::Schedule.add_missing_rrule_validations!({ rule_type: 'IceCube::MonthlyRule', validations: { day_of_week: { '1' => ['1'] } } }, data)

      assert_equal({ 1 => [1] }, monthly_dow_hash[:validations][:day_of_week])

      monthly_bad_dow = DataCycleCore::Schedule.add_missing_rrule_validations!({ rule_type: 'IceCube::MonthlyRule', validations: { day_of_week: 'not-json' } }, data)

      assert_not(monthly_bad_dow[:validations].key?(:day_of_week))

      monthly_dom = DataCycleCore::Schedule.add_missing_rrule_validations!({ rule_type: 'IceCube::MonthlyRule', validations: { day_of_month: '[15]' } }, data)

      assert_equal([15], monthly_dom[:validations][:day_of_month])

      monthly_bad_dom = DataCycleCore::Schedule.add_missing_rrule_validations!({ rule_type: 'IceCube::MonthlyRule', validations: { day_of_month: 'not-json' } }, data)

      assert_not(monthly_bad_dom[:validations].key?(:day_of_month))
    end

    test 'to_h_from_schedule_params transforms weekly/monthly/yearly/single params' do
      value = {
        '0' => { 'id' => nil, 'start_time' => { 'time' => '2020-01-01 09:00' }, 'rrules' => [{ 'rule_type' => 'IceCube::WeeklyRule', 'validations' => { 'day' => ['1', '3'] } }] },
        '1' => { 'start_time' => { 'time' => '2020-01-01 09:00' }, 'rrules' => [{ 'rule_type' => 'IceCube::SingleOccurrenceRule' }] },
        '2' => { 'start_time' => { 'time' => '2020-01-01 09:00' }, 'rrules' => [{ 'rule_type' => 'IceCube::MonthlyRule', 'validations' => { 'day' => ['1'], 'day_of_week' => '{"1":[1]}' } }] },
        '3' => { 'start_time' => { 'time' => '2020-01-01 09:00' }, 'rrules' => [{ 'rule_type' => 'IceCube::MonthlyRule', 'validations' => { 'day_of_month' => '[15]' } }] },
        '4' => { 'start_time' => { 'time' => '2020-01-01 09:00' }, 'rrules' => [{ 'rule_type' => 'IceCube::YearlyRule', 'validations' => { 'day' => ['1'] } }] }
      }

      result = DataCycleCore::Schedule.to_h_from_schedule_params(value)

      assert_equal(5, result.size)
    end

    test 'to_h_from_schedule_params recovers from invalid JSON and end_time durations' do
      value = {
        '0' => { 'start_time' => { 'time' => '2020-01-01 09:00' }, 'end_time' => { 'time' => '2020-01-01 17:00' }, 'rrules' => [{ 'rule_type' => 'IceCube::DailyRule' }] },
        '1' => { 'start_time' => { 'time' => '2020-01-01 09:00' }, 'rrules' => [{ 'rule_type' => 'IceCube::MonthlyRule', 'validations' => { 'day_of_week' => 'not-json' } }] },
        '2' => { 'start_time' => { 'time' => '2020-01-01 09:00' }, 'rrules' => [{ 'rule_type' => 'IceCube::MonthlyRule', 'validations' => { 'day_of_month' => 'not-json' } }] }
      }

      result = DataCycleCore::Schedule.to_h_from_schedule_params(value)

      assert_equal(3, result.size)
    end

    test 'to_h_from_opening_time_params transforms opening-time params' do
      assert_nil(DataCycleCore::Schedule.to_h_from_opening_time_params(nil))

      value = {
        '0' => {
          'valid_from' => '2020-01-01',
          'valid_until' => '2020-12-31',
          'holiday' => 'false',
          'rrules' => [{ 'validations' => { 'day' => ['1', '2'] } }],
          'time' => { '0' => { 'id' => nil, 'opens' => '09:00', 'closes' => '17:00' } }
        },
        '1' => {
          'datahash' => {
            'valid_from' => '2020-01-01',
            'holiday' => 'true',
            'rrules' => [{ 'validations' => { 'day' => ['3'] } }],
            'time' => { '0' => { 'datahash' => { 'id' => nil, 'opens' => '10:00', 'closes' => '12:00' } } }
          }
        }
      }

      result = DataCycleCore::Schedule.to_h_from_opening_time_params(value)

      assert_equal(2, result.size)
    end

    # ---------------------------------------------------------------------------
    # class-level SQL / maintenance
    # ---------------------------------------------------------------------------

    test 'schedule_occurrences_sql builds a sanitized function definition' do
      sql = DataCycleCore::Schedule.schedule_occurrences_sql(range_start: Date.new(2020, 1, 1), range_end: Date.new(2025, 1, 1))

      assert_includes(sql, 'CREATE OR REPLACE FUNCTION')
    end

    test 'rebuild_occurrences recreates the occurrences function' do
      assert_nothing_raised do
        DataCycleCore::Schedule.rebuild_occurrences
      end
    end
  end
end

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

      # Every case reading a generated occurrences column reads whatever definition the database
      # holds, and the materialization window is interpolated into that definition when it is
      # created -- so a database set up on an earlier day carries an earlier window edge than
      # occurrences_range computes now. Installing it here runs the whole file against the current
      # definition, the one the migration installs too.
      DataCycleCore::Schedule.connection.exec_query(DataCycleCore::Schedule.schedule_occurrences_sql(**DataCycleCore::Schedule.occurrences_range))
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

    # Expands a rule through the database function backing the generated occurrences columns.
    #
    # @param dtstart [ActiveSupport::TimeWithZone] start of the series
    # @param rrule [String, nil] the rule to expand
    # @param rdate [Array<ActiveSupport::TimeWithZone>] additional dates
    # @param exdate [Array<ActiveSupport::TimeWithZone>] excluded days
    # @param time_zone [String, nil] TimeZone to run the statement under, to prove the result is
    #   independent of the writing connection
    # @return [Array<ActiveSupport::TimeWithZone>] start of every materialized occurrence
    def db_occurrences(dtstart, rrule, rdate: [], exdate: [], time_zone: nil)
      # rendered as text in a fixed zone, so the session TimeZone cannot colour the comparison
      sql = <<~SQL.squish
        SELECT to_char(
          lower(unnest(generate_schedule_occurences_array(
            ?::timestamp with time zone,
            ?::character varying,
            ?::timestamp with time zone[],
            ?::timestamp with time zone[],
            INTERVAL '45 minutes'
          ))) AT TIME ZONE 'Europe/Vienna', 'YYYY-MM-DD HH24:MI:SS'
        ) AS occurrence
      SQL

      connection = DataCycleCore::Schedule.connection
      # SET LOCAL, so the transaction the test runs in undoes it -- SET TIME ZONE DEFAULT would
      # restore whatever the server hands a fresh session, not the UTC the Rails adapter set
      connection.exec_query("SET LOCAL TIME ZONE '#{time_zone}'") if time_zone.present?
      connection.select_values(
        ActiveRecord::Base.send(
          :sanitize_sql_array,
          # iso8601 keeps the offset in the literal, so the binds do not resolve through the session TimeZone either
          [sql, dtstart.iso8601, rrule, "{#{rdate.map(&:iso8601).join(',')}}", "{#{exdate.map(&:iso8601).join(',')}}"]
        )
      ).map { |o| Time.find_zone('Europe/Vienna').parse(o) }
    end

    test 'occurrences columns keep the last occurrence of a rule with a UTC UNTIL' do
      dtstart = Time.zone.parse("#{1.year.from_now.year}-07-06 11:15")
      rule_until = dtstart + 1.day
      schedule = schedule_with_rule(IceCube::Rule.daily.until(rule_until), dtstart:, duration: 45.minutes)

      assert_includes(schedule.rrule, "UNTIL=#{rule_until.utc.strftime('%Y%m%dT%H%M%S')}Z")

      schedule.save
      schedule.reload

      assert_equal([dtstart, rule_until], schedule.schedule_object.all_occurrences.map(&:start_time))
      assert_equal([dtstart, rule_until], Array(schedule.occurrences_array).map { |o| o.begin.in_time_zone })
    end

    test 'generate_schedule_occurences_array interprets a UTC UNTIL as UTC' do
      dtstart = Time.zone.parse("#{1.year.from_now.year}-07-06 11:15")
      rule_until = dtstart + 1.day

      assert_equal(
        [dtstart, rule_until],
        db_occurrences(dtstart, "FREQ=DAILY;UNTIL=#{rule_until.utc.strftime('%Y%m%dT%H%M%S')}Z")
      )
    end

    # The series from the ticket, built the way the feed delivers it: six weekdays of BYDAY, the
    # start time repeated as BYHOUR/BYMINUTE, 45 minutes long, ending on its own last occurrence.
    # Whichever form that endDate reaches the column in -- the wall time carrying a Z, which is what
    # to_h_from_schema_org writes, or the UTC instant of that occurrence, which is what a converted
    # UNTIL looks like -- the last day has to survive. It is the second form that lost it.
    test '[#51616] regression: an imported weekly series keeps the occurrence its UNTIL falls on' do
      monday = 1.year.from_now.next_occurring(:monday).change(hour: 11, min: 15)
      tuesday = monday + 1.day
      schedule = DataCycleCore::Schedule.new.from_h(DataCycleCore::Schedule.to_h_from_schema_org({
        'startDate' => monday.to_date.iso8601, 'startTime' => '11:15',
        'endDate' => tuesday.to_date.iso8601, 'endTime' => '11:15',
        'duration' => 'PT45M', 'repeatFrequency' => 'P1W',
        'byDay' => ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'].map { |d| "https://schema.org/#{d}" },
        'scheduleTimezone' => 'Europe/Vienna'
      }))
      schedule.save
      schedule.reload

      assert_equal("FREQ=WEEKLY;UNTIL=#{tuesday.strftime('%Y%m%dT%H%M%S')}Z;BYHOUR=11;BYMINUTE=15;BYDAY=MO,TU,WE,TH,FR,SA", schedule.rrule)
      assert_equal(
        schedule.schedule_object.all_occurrences.map { |o| [o.start_time, o.end_time] },
        Array(schedule.occurrences_array).map { |o| [o.begin.in_time_zone, o.end.in_time_zone] }
      )
      assert_equal([monday, tuesday], Array(schedule.occurrences_array).map { |o| o.begin.in_time_zone })

      as_utc_instant = schedule.rrule.sub(/UNTIL=\d{8}T\d{6}Z/, "UNTIL=#{tuesday.utc.strftime('%Y%m%dT%H%M%S')}Z")

      assert_equal([monday, tuesday], db_occurrences(monday, as_utc_instant), as_utc_instant)
    end

    # The last Sunday of October and of March, when a duration can run through the change itself.
    #
    # @param month [Integer] 10 for the autumn change, 3 for the spring one
    # @return [Date] the Saturday before it, so a 23:00 occurrence spans the night
    def evening_before_the_clock_change(month)
      last = Date.new(1.year.from_now.year, month, -1)

      last.downto(last - 6).find(&:sunday?).prev_day
    end

    # A series recurring at 23:00 has an occurrence running through the night the clocks change, and
    # a duration of a day or more can span the change from a dtstart sitting on it. IceCube resolves
    # the duration once at dtstart -- calendar parts on the wall clock, time parts absolute -- and
    # reuses those seconds for every occurrence, so a "1 day" event starting that evening lasts 25
    # hours, and every one of its later occurrences lasts 25 hours too. The materialized column has
    # to land on the same instants, or filters and detail page part ways again.
    test 'a series through a clock change materializes what IceCube expands, whatever its duration' do
      [10, 3].each do |month|
        saturday = evening_before_the_clock_change(month)

        [["#{saturday} 23:00", nil], ["#{saturday} 23:00", 'FREQ=DAILY;BYHOUR=23'], ["#{saturday - 7} 23:00", 'FREQ=DAILY;BYHOUR=23'], ["#{saturday} 01:00", nil]].each do |start, rule|
          dtstart = Time.zone.parse(start)
          rrule = rule && "#{rule};UNTIL=#{(dtstart + 4.days).utc.strftime('%Y%m%dT%H%M%S')}Z"

          [45.minutes, 3.hours, 25.hours, 1.day, DataCycleCore::Schedule.parse_iso8601_duration('P4DT8H'), 1.month].each do |duration|
            schedule = DataCycleCore::Schedule.new(dtstart:, rrule:, duration:)
            schedule.save
            schedule.reload

            assert_equal(
              schedule.schedule_object.all_occurrences.map { |o| [o.start_time, o.end_time] },
              Array(schedule.occurrences_array).map { |r| [r.begin.in_time_zone, r.end.in_time_zone] },
              "#{duration.inspect} from #{start}#{rrule && ', recurring'}"
            )
          end
        end
      end
    end

    test 'excluded days do not depend on the writing session TimeZone' do
      # 01:00 local is 23:00 UTC the day before, so an exdate that evening excludes a different day
      # depending on the zone the truncation runs in -- at 11:15 the two zones never disagree.
      dtstart = Time.zone.parse("#{1.year.from_now.year}-07-06 01:00")
      rrule = "FREQ=DAILY;UNTIL=#{(dtstart + 4.days).utc.strftime('%Y%m%dT%H%M%S')}Z"
      exdate = [dtstart + 1.day + 21.hours] # 07.07. 22:00 local, 20:00 UTC

      assert_equal(
        db_occurrences(dtstart, rrule, exdate:, time_zone: 'UTC'),
        db_occurrences(dtstart, rrule, exdate:, time_zone: 'Europe/Vienna')
      )
      # the 07.07. occurrence is the one the exdate covers in Europe/Vienna
      assert_equal(
        [dtstart, dtstart + 2.days, dtstart + 3.days, dtstart + 4.days],
        db_occurrences(dtstart, rrule, exdate:)
      )
    end

    # The opening hours series recur at midnight, so the last one inside the window sits exactly on
    # range_end -- and get_occurrences yields it, so the window filter must not drop it again.
    test 'an occurrence landing exactly on the end of the materialization window survives' do
      range_end = DataCycleCore::Schedule.occurrences_range[:range_end]
      dtstart = Time.zone.parse("#{range_end.prev_day.iso8601} 00:00")
      rrule = "FREQ=DAILY;BYHOUR=0;UNTIL=#{(dtstart + 10.days).utc.strftime('%Y%m%dT%H%M%S')}Z"

      assert_equal([dtstart, dtstart + 1.day], db_occurrences(dtstart, rrule))
    end

    # The guard at the top of the function skips a row whose dtstart lies past the window, and has to
    # measure that against the same whole day the filter below it does -- otherwise a schedule that
    # starts on the window's last day materializes nothing, while the identical occurrence reached
    # from an earlier dtstart is kept.
    test 'a schedule whose dtstart falls on the last day of the window is still materialized' do
      dtstart = Time.zone.parse("#{DataCycleCore::Schedule.occurrences_range[:range_end].iso8601} 10:00")
      rrule = "FREQ=DAILY;UNTIL=#{(dtstart + 2.hours).utc.strftime('%Y%m%dT%H%M%S')}Z"

      assert_equal([dtstart], db_occurrences(dtstart, rrule))
    end

    # An endless rule gets the end of the window appended as an UNTIL of its own, and pg_rrule reads
    # a date as midnight of that date -- so a date would cut the opening-hours series at BYHOUR=0 on
    # the very day the widened bounds are there to keep.
    test 'an endless rule keeps a midnight occurrence on the last day of the window' do
      dtstart = Time.zone.parse("#{DataCycleCore::Schedule.occurrences_range[:range_end].prev_day.iso8601} 00:00")

      assert_equal([dtstart, dtstart + 1.day], db_occurrences(dtstart, 'FREQ=DAILY;BYHOUR=0'))
    end

    test 'rdates outside the materialization window are dropped, inside it they survive a dtstart past its end' do
      dtstart = Time.zone.parse("#{1.year.from_now.year}-07-06 11:15")
      in_window = dtstart + 30.days
      outside = 50.years.from_now.change(hour: 10)

      assert_equal([dtstart, in_window], db_occurrences(dtstart, nil, rdate: [in_window, outside]))
      assert_equal([in_window], db_occurrences(50.years.from_now, nil, rdate: [in_window]))
    end

    # One case per bound the conversion checks. Each of these reaches the column as a Z form, so the
    # conversion has to recognise that the digits are not a date it can safely cast and hand the rule
    # on unchanged -- the contract being that the Z then makes no difference at all, which is what
    # comparing against the same rule without it asserts. The two occurrences a day are what makes
    # the comparison bite: an out of range date makes the cast raise, but an hour of 24, a minute of
    # 60 and a second of 60 are rolled over by Postgres instead, so without the check they convert
    # silently and move the end of the series across the 01:00 or the 13:00 occurrence.
    test 'a UTC UNTIL that cannot be converted expands exactly as if it carried no Z' do
      dtstart = Time.zone.parse("#{1.year.from_now.year}-07-06 01:00")
      year = dtstart.year

      {
        '00001231T230000' => 'a year below 1',
        '99991231T230000' => 'a year that the shift into Europe/Vienna moves past 9999',
        "#{year}0006T091500" => 'a month below 1',
        "#{year}1306T091500" => 'a month above 12',
        "#{year}0700T091500" => 'a day below 1',
        "#{year}0632T091500" => 'a day above 31',
        "#{year}0631T091500" => 'a 31st in a month that has 30 days',
        "#{year}0229T091500" => 'a 29 February in a year that has none',
        "#{year}0706T241500" => 'an hour above 23',
        "#{year}0706T116000" => 'a minute above 59',
        "#{year}0706T111560" => 'a second above 59'
      }.each do |until_value, reason|
        assert_equal(
          db_occurrences(dtstart, "FREQ=DAILY;BYHOUR=1,13;UNTIL=#{until_value}"),
          db_occurrences(dtstart, "FREQ=DAILY;BYHOUR=1,13;UNTIL=#{until_value}Z"),
          "#{reason} (UNTIL=#{until_value}Z) must be handed to pg_rrule unconverted"
        )
      end
    end

    # 23:00 UTC is midnight in Europe/Vienna in winter and 01:00 in summer, so the same UNTIL digits
    # have to end the series on different sides of a 00:30 occurrence depending on the season. Both
    # halves fail if the conversion ever hard-codes a fixed offset instead of asking the zone.
    test 'the same UTC UNTIL converts to one hour later in winter and two hours later in summer' do
      year = 1.year.from_now.year

      winter = Time.zone.parse("#{year}-01-15 00:30")
      summer = Time.zone.parse("#{year}-07-15 00:30")

      assert_equal(
        [winter],
        db_occurrences(winter, "FREQ=DAILY;UNTIL=#{year}0115T230000Z"),
        'in winter the UNTIL is midnight, which ends the series before the 00:30 occurrence of the next day'
      )
      assert_equal(
        [summer, summer + 1.day],
        db_occurrences(summer, "FREQ=DAILY;UNTIL=#{year}0715T230000Z"),
        'in summer the same UNTIL is 01:00, which keeps the 00:30 occurrence of the next day'
      )
    end

    # A rule without an UNTIL is endless, and a generated column cannot be. The materialization
    # appends the end of the window as an UNTIL of its own, so the series has to stop there.
    test 'an endless rule is materialized up to the end of the window and no further' do
      range_end = DataCycleCore::Schedule.occurrences_range[:range_end]
      dtstart = Time.zone.parse("#{1.year.from_now.year}-07-06 11:15")
      yearly = (dtstart.year..range_end.year).map { |year| dtstart.change(year:) }

      assert_operator(yearly.last, :<, range_end.in_time_zone, 'the last expected occurrence has to sit inside the window')
      assert_equal(yearly, db_occurrences(dtstart, 'FREQ=YEARLY'))
    end

    # RFC 5545 gives UNTIL three forms and no fourth: a UTC instant (20260707T091500Z), a floating
    # local time (20260707T091500) and a date (20260707). A zone never travels with UNTIL - TZID
    # belongs to DTSTART - so the only question the conversion has to answer is whether the digits
    # are UTC, which the trailing Z answers. The four tests below cover the two writers that decide
    # which form reaches the column, and the two forms the conversion deliberately does not touch.
    test 'a rule UNTIL is serialized as a UTC instant, whatever zone it was given in' do
      dtstart = Time.zone.parse("#{1.year.from_now.year}-07-06 11:15")
      rule_until = dtstart + 1.day
      expected = "FREQ=DAILY;UNTIL=#{rule_until.utc.strftime('%Y%m%dT%H%M%S')}Z"

      ['Europe/Vienna', 'Europe/Istanbul', 'UTC'].each do |zone|
        assert_equal(
          expected,
          schedule_with_rule(IceCube::Rule.daily.until(rule_until.in_time_zone(zone)), dtstart:).rrule,
          "an UNTIL given in #{zone} must serialize to the same UTC instant"
        )
      end
    end

    test 'an imported schedule writes its UNTIL as a UTC instant, whatever scheduleTimezone it carries' do
      ['Europe/Vienna', 'Europe/Istanbul', 'UTC'].each do |zone|
        hash = DataCycleCore::Schedule.to_h_from_schema_org({
          'startDate' => '2026-07-06', 'startTime' => '11:15',
          'endDate' => '2026-07-07', 'endTime' => '11:15',
          'repeatFrequency' => 'P1D', 'scheduleTimezone' => zone
        })

        assert_match(
          /;UNTIL=\d{8}T\d{6}Z(;|\z)/,
          DataCycleCore::Schedule.new.from_h(hash).rrule,
          "an import carrying scheduleTimezone #{zone} must still write a UTC UNTIL"
        )
      end
    end

    # A zone-less UNTIL is a floating local time: its digits are a wall clock reading and have to
    # stay one, which is why the conversion matches the Z form only. An UNTIL an hour before the
    # next occurrence therefore has to end the series before it - read as UTC, 10:15 would land at
    # 12:15 in Europe/Vienna and keep the occurrence the rule ends on.
    test 'a floating UNTIL ends the series at its own wall clock time' do
      dtstart = Time.zone.parse("#{1.year.from_now.year}-07-06 11:15")
      last_day = dtstart + 1.day
      on_the_occurrence = "FREQ=DAILY;UNTIL=#{last_day.strftime('%Y%m%dT%H%M%S')}"

      assert_equal(
        [dtstart],
        db_occurrences(dtstart, "FREQ=DAILY;UNTIL=#{(last_day - 1.hour).strftime('%Y%m%dT%H%M%S')}"),
        'an UNTIL of 10:15 ends the series before the 11:15 occurrence of that day'
      )
      assert_equal(
        [dtstart, last_day],
        db_occurrences(dtstart, on_the_occurrence),
        'an UNTIL of 11:15 keeps the 11:15 occurrence of that day'
      )
      assert_equal(
        db_occurrences(dtstart, on_the_occurrence, time_zone: 'UTC'),
        db_occurrences(dtstart, on_the_occurrence, time_zone: 'Europe/Vienna'),
        'the wall clock reading does not depend on the session TimeZone'
      )
    end

    # A date UNTIL carries no time at all, and pg_rrule reads it as midnight of that date, so a
    # series at 11:15 ends the day before its UNTIL date. This MR leaves that reading untouched;
    # the test pins it so a pg_rrule upgrade that changes it fails here rather than in the data.
    test 'a date only UNTIL ends the series at midnight of its date' do
      dtstart = Time.zone.parse("#{1.year.from_now.year}-07-06 11:15")
      last_day = dtstart + 1.day

      assert_equal(
        [dtstart],
        db_occurrences(dtstart, "FREQ=DAILY;UNTIL=#{last_day.strftime('%Y%m%d')}"),
        'midnight of the UNTIL date is before the 11:15 occurrence of that day'
      )
      assert_equal(
        [dtstart, last_day],
        db_occurrences(dtstart, "FREQ=DAILY;UNTIL=#{(last_day + 1.day).strftime('%Y%m%d')}"),
        'every day before the UNTIL date is kept in full'
      )
    end
  end
end

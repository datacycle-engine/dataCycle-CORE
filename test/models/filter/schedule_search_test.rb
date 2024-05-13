# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ScheduleSearchTest < ActiveSupport::TestCase
    def schedule_hash(start_time, rule_type = nil, until_date = nil, validations = nil)
      rrule_values = [{ 'rule_type' => "IceCube::#{rule_type.classify}Rule", 'interval' => '1', 'until' => until_date, 'validations' => validations }] if rule_type.present?
      [{
        'start_time' => {
          'time' => start_time,
          'zone' => 'Europe/Vienna'
        },
        'rtimes' => [],
        'duration' => 1.hour.to_i,
        'rrules' => rrule_values
      }]
    end

    test 'test query for event_schedule with single occurrence' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(1, items.count)
    end

    test 'test query for event_schedule with single occurrence before search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.end_of_day - 1.day - 1.hour) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with single occurrence after search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.beginning_of_day + 1.day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with single occurrence and daily rrule' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now, 'Daily', Time.zone.now.end_of_day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(1, items.count)
    end

    test 'test query for event_schedule with multiple occurrences and daily rrule' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now - 10.days, 'Daily', Time.zone.now.end_of_day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(1, items.count)
    end

    test 'test query for event_schedule with single occurrence and daily rrule before search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.end_of_day - 1.day - 1.hour, 'Daily', Time.zone.now.end_of_day - 1.day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with multiple occurrences and daily rrule before search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.end_of_day - 10.days - 1.hour, 'Daily', Time.zone.now.end_of_day - 1.day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with single occurrence and daily rrule after search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.beginning_of_day + 1.day, 'Daily', Time.zone.now.end_of_day + 1.day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with multiple occurrences and daily rrule after search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.beginning_of_day + 1.day, 'Daily', Time.zone.now.end_of_day + 10.days) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with single occurrence and weekly rrule' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now, 'Weekly', Time.zone.now.end_of_day, { 'day' => [Date.current.wday] }) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(1, items.count)
    end

    test 'test query for event_schedule with multiple occurrences and weekly rrule' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now - 3.weeks, 'Weekly', Time.zone.now.end_of_day, { 'day' => [Date.current.wday] }) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(1, items.count)
    end

    test 'test query for event_schedule with single occurrence and weekly rrule before search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.end_of_day - 1.day - 1.hour, 'Weekly', Time.zone.now.end_of_day - 1.day, { 'day' => [(Date.current - 1.day).wday] }) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with multiple occurrences and weekly rrule before search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.end_of_day - 2.weeks - 1.day - 1.hour, 'Weekly', Time.zone.now.end_of_day - 1.day, { 'day' => [(Date.current - 1.day).wday] }) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with single occurrence and weekly rrule after search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.beginning_of_day + 1.day, 'Weekly', Time.zone.now.end_of_day + 1.day, { 'day' => [(Date.current + 1.day).wday] }) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with multiple occurrences and weekly rrule after search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.beginning_of_day + 1.day, 'Weekly', Time.zone.now.end_of_day + 2.weeks, { 'day' => [(Date.current + 1.day).wday] }) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with single occurrence and yearly rrule' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now, 'Yearly', Time.zone.now.end_of_day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(1, items.count)
    end

    test 'test query for event_schedule with multiple occurrences and yearly rrule' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now - 4.years, 'Yearly', Time.zone.now.end_of_day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(1, items.count)
    end

    test 'test query for event_schedule with single occurrence and yearly rrule before search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.end_of_day - 1.day - 1.hour, 'Yearly', Time.zone.now.end_of_day - 1.day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with multiple occurrences and yearly rrule before search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.end_of_day.utc - 2.years - 1.day - 1.hour, 'Yearly', Time.zone.now.end_of_day.utc - 1.day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)

      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with single occurrence and yearly rrule after search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.beginning_of_day + 1.day, 'Yearly', Time.zone.now.end_of_day + 1.day) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    test 'test query for event_schedule with multiple occurrences and yearly rrule after search date' do
      create_content('Event', { name: 'DDD0', event_schedule: schedule_hash(Time.zone.now.beginning_of_day + 1.day, 'Yearly', Time.zone.now.end_of_day + 2.years) })

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(0, items.count)
    end

    private

    def create_content(template_name, data = {})
      DataCycleCore::TestPreparations.create_content(template_name:, data_hash: data)
    end
  end
end

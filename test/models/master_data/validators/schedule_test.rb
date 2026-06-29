# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Validators::Schedule do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Validators::Schedule
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'schedule',
        'validations' => {
          'valid_dates' => true
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly validates a schedule object' do
      schedule_object = IceCube::Schedule.new(Time.zone.now) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9))
      end
      schedule = DataCycleCore::Schedule.new(thing_id: SecureRandom.uuid, relation: 'schedule')
      schedule.schedule_object = schedule_object

      assert_equal(no_error_hash, subject.new([schedule.to_h], template_hash).error)
    end

    # it 'properly returns a warning if no data are given' do
    #   error_hash = subject.new(nil, template_hash)
    #   assert_equal(0, error_hash.error[:error].size)
    #   assert_equal(1, error_hash.error[:warning].size)
    # end

    it 'rejects arbitrary objects' do
      test_cases = [10, :wednesday, 'hallo']
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)

        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'properly validates a schedule object without valid dates' do
      timestamp = Time.zone.now.change(hour: 9, minute: 0)
      schedule_object = IceCube::Schedule.new(timestamp) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9).day((timestamp - 1.day).wday).until(timestamp.end_of_day))
      end
      schedule = DataCycleCore::Schedule.new(thing_id: SecureRandom.uuid, relation: 'event_schedule')
      schedule.schedule_object = schedule_object

      assert_predicate(subject.new([schedule.to_h], template_hash).error[:error], :present?)
    end

    it 'properly validates a schedule object with valid dates' do
      timestamp = Time.zone.now.change(hour: 9, minute: 0)
      schedule_object = IceCube::Schedule.new(timestamp) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9).day(timestamp.wday).until(timestamp.end_of_day))
      end
      schedule = DataCycleCore::Schedule.new(thing_id: SecureRandom.uuid, relation: 'event_schedule')
      schedule.schedule_object = schedule_object

      assert_predicate(subject.new([schedule.to_h], template_hash).error[:error], :blank?)
    end
  end

  describe 'validation error branches' do
    let(:validator) { subject.new([], { 'label' => 'Test' }) }

    it 'collects an error per invalid schedule field' do
      bad_item = { thing_id: 'not-a-uuid', relation: '', start_time: 'bad', rdate: 'bad', rrule: ['not-a-hash'] }
      paths = subject.new([bad_item], { 'label' => 'Test' }).error[:error].values.flatten.pluck(:path)

      assert_includes paths, 'validation.errors.schedule.thing_id'
      assert_includes paths, 'validation.errors.schedule.relation'
      assert_includes paths, 'validation.errors.schedule.time'
      assert_includes paths, 'validation.errors.schedule.date_time_array'
      assert_includes paths, 'validation.errors.schedule.rrule'
    end

    it 'flags a required but blank schedule' do
      paths = subject.new(nil, { 'validations' => { 'required' => true } }).error[:error].values.flatten.pluck(:path)

      assert_includes paths, 'validation.errors.required'
    end

    it 'flags a schedule without a closed range' do
      item = { 'rrules' => [{ 'rule_type' => 'IceCube::WeeklyRule' }] }
      paths = subject.new([item], { 'validations' => { 'closed_range' => true } }).error[:error].values.flatten.pluck(:path)

      assert_includes paths, 'validation.errors.schedule.until_missing'
    end

    it 'warns when the schedule recurs beyond the soft maximum date' do
      item = { 'rrules' => [{ 'until' => '2030-01-01' }], 'start_time' => { 'time' => '2030-01-01' } }
      paths = subject.new([item], { 'validations' => { 'soft_max_date' => '2020-01-01' } }).error[:warning].values.flatten.pluck(:path)

      assert_includes paths, 'validation.errors.schedule.until_too_far'
    end

    it 'date_time? returns false for unparseable values' do
      assert_not validator.send(:date_time?, Object.new)
      assert validator.send(:date_time?, '2024-01-01')
    end

    it 'date_time_array? validates each element' do
      assert_not validator.send(:date_time_array?, 'not-an-array')
      assert_not validator.send(:date_time_array?, [Object.new])
      assert validator.send(:date_time_array?, ['2024-01-01'])
    end

    it 'rrule? validates recurrence rule hashes' do
      assert validator.send(:rrule?, nil)
      assert_not validator.send(:rrule?, 'not-a-hash')
      assert validator.send(:rrule?, IceCube::Rule.daily.to_hash)
      assert_not validator.send(:rrule?, { rule_type: 'IceCube::DailyRule', interval: 0 })
    end
  end
end

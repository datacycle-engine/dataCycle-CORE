# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Schedule do
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

      assert(subject.new([schedule.to_h], template_hash).error.dig(:error).present?)
    end

    it 'properly validates a schedule object with valid dates' do
      timestamp = Time.zone.now.change(hour: 9, minute: 0)
      schedule_object = IceCube::Schedule.new(timestamp) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9).day(timestamp.wday).until(timestamp.end_of_day))
      end
      schedule = DataCycleCore::Schedule.new(thing_id: SecureRandom.uuid, relation: 'event_schedule')
      schedule.schedule_object = schedule_object

      assert(subject.new([schedule.to_h], template_hash).error.dig(:error).blank?)
    end
  end
end

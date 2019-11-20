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
        'type' => 'schedule'
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly validates a schedule object' do
      schedule_object = IceCube::Schedule.new(Time.zone.now) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9))
      end
      assert_equal(no_error_hash, subject.new(schedule_object, template_hash).error)
    end

    it 'properly returns a warning if no data are given' do
      error_hash = subject.new(nil, template_hash)
      assert_equal(0, error_hash.error[:error].size)
      assert_equal(1, error_hash.error[:warning].size)
    end

    it 'rejects arbitrary objects' do
      test_cases = [10, :wednesday, 'hallo']
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end
  end
end

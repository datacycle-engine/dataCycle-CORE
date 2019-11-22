# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::Schedule do
  subject do
    DataCycleCore::MasterData::Differs::Schedule
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'schedule'
      }
    end

    it 'properly diffs equal schedule objects' do
      a_schedule = IceCube::Schedule.new(Time.zone.now) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9))
      end
      a_hash = a_schedule.to_h
      [[a_schedule, a_hash], [a_hash, a_schedule], [a_schedule, a_schedule], [a_hash, a_hash]].each do |a, b|
        assert_nil(subject.new(a, b).diff_hash)
        assert_nil(subject.new(a, b, template_hash).diff_hash)
      end
    end

    it 'recognizes a deleted value' do
      a = IceCube::Schedule.new(Time.zone.now) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9))
      end
      [a, a.to_h].each do |item|
        assert_equal(['-', a.to_h], subject.new(item, nil).diff_hash)
      end
    end

    it 'recognizes an inserted value' do
      a = IceCube::Schedule.new(Time.zone.now) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9))
      end
      [a, a.to_h].each do |item|
        assert_equal(['+', a.to_h], subject.new(nil, item, template_hash).diff_hash)
        assert_equal(['+', a.to_h], subject.new(nil, item).diff_hash)
      end
    end
  end
end

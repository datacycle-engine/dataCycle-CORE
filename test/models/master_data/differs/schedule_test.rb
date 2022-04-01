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
      schedule = IceCube::Schedule.new(Time.zone.now) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9))
      end
      a_schedule = DataCycleCore::Schedule.new(id: SecureRandom.uuid)
      a_schedule.schedule_object = schedule
      a_hash = a_schedule.to_h
      [[a_schedule, a_hash], [a_hash, a_schedule], [a_schedule, a_schedule], [a_hash, a_hash]].each do |a, b|
        assert_nil(subject.new([a], [b]).diff_hash)
        assert_nil(subject.new([a], [b], template_hash).diff_hash)
      end
    end

    it 'recognizes a deleted value' do
      a_schedule = IceCube::Schedule.new(Time.zone.now) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9))
      end
      a = DataCycleCore::Schedule.new(id: SecureRandom.uuid)
      a.schedule_object = a_schedule
      [[a], [a.to_h]].each do |item|
        assert_equal([['-', [a.id]]], subject.new(item, nil).diff_hash)
      end
    end

    it 'recognizes an inserted value' do
      a_schedule = IceCube::Schedule.new(Time.zone.now) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9))
      end
      a = DataCycleCore::Schedule.new(id: SecureRandom.uuid)
      a.schedule_object = a_schedule
      [[a], [a.to_h]].each do |item|
        assert_equal([['+', [a.id]]], subject.new(nil, item, template_hash).diff_hash)
        assert_equal([['+', [a.id]]], subject.new(nil, item).diff_hash)
      end
    end

    it 'recognizes hashes from UI as existing schedules without changes' do
      start_time = Time.zone.now.change(hour: 9, minute: 0)
      a_schedule = IceCube::Schedule.new(start_time, duration: 0) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9))
      end
      a = DataCycleCore::Schedule.new(id: SecureRandom.uuid)
      a.schedule_object = a_schedule
      a_hash = [a.serialize_schedule_object.to_h.with_indifferent_access.compact]

      schedule_hash = { 'event_schedule' => { '0' =>
        {
          'id' => a.id,
          'start_time' => { 'time' => start_time.strftime('%Y-%m-%d %H:%M') },
          'rrules' => [{ 'rule_type' => 'IceCube::DailyRule', 'interval' => '1' }]
        } } }

      template = DataCycleCore::Thing.find_by(template: true, template_name: 'Event')
      transformed_schedule_hash = DataCycleCore::DataHashService.flatten_datahash_value(schedule_hash, template.schema).dig('event_schedule')

      assert_nil(subject.new(a_hash, transformed_schedule_hash).diff_hash)
      assert_nil(subject.new(a_hash, transformed_schedule_hash, template_hash).diff_hash)
    end
  end
end

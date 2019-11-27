# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ScheduleTest < ActiveSupport::TestCase
    # def setup
    #   @schedule = DataCycleCore::Schedule.new
    #   @dtstart = Time.parse('2019-11-20T9:00').in_time_zone
    #   @dtend = Time.parse('2020-01-04T16:00').in_time_zone
    #   @schedule.schedule_object = IceCube::Schedule.new(@dtstart, end_time: @dtend) do |s|
    #     s.duration = 7.hours
    #     s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9).until(@dtend))
    #   end
    #   @schedule.serialize_schedule_object
    # end
    #
    # test 'serialize to hash and self apply --> unchanged' do
    #   schedule_hash = @schedule.to_h
    #   @schedule.from_hash(schedule_hash)
    #   assert(schedule_hash == @schedule.to_h)
    # end
    #
    # test 'serialize to hash, create from hash' do
    #   schedule_hash = @schedule.to_h
    #   [:start_time, :end_time, :rrules, :rtimes, :extimes, :dtstart, :dtend].each do |key|
    #     assert(schedule_hash.key?(key))
    #   end
    #   schedule2 = DataCycleCore::Schedule.new.from_hash(schedule_hash)
    #   assert(schedule_hash == schedule2.to_h)
    # end

    test 'save schedule, make sure all table columns are correctly filled' do
      schedule = DataCycleCore::Schedule.new
      dtstart = Time.parse('2019-11-20T9:00').in_time_zone
      dtend = Time.parse('2020-01-04T16:00').in_time_zone
      schedule.schedule_object = IceCube::Schedule.new(dtstart, { end_time: dtend, duration: 7.hours.to_i }) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9).until(dtend))
      end

      [:id, :dtstart, :dtend, :duration, :rrule].each do |attribute|
        assert_nil(schedule.send(attribute))
      end
      [:rdate, :exdate].each do |attribute|
        assert([], schedule.send(attribute))
      end

      schedule.save
      assert(schedule.id.present?)
      assert(dtstart, schedule.dtstart)
      assert(dtend, schedule.dtend)
    end
  end
end

# frozen_string_literal: true

require 'test_helper'
require 'virtual_attributes_test_utilities'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe 'DataCycleCore::Utility::Virtual::Schedule#start_date' do
  include VirtualAttributeTestUtilities

  subject do
    DataCycleCore::Utility::Virtual::Schedule
  end

  it 'should return correct start_date for schedule' do
    dtstart = Time.parse('2019-11-20T9:00').in_time_zone
    dtend = Time.parse('2020-01-04T16:00').in_time_zone
    duration = 7.hours
    schedule = DataCycleCore::Schedule.new
    schedule.schedule_object = IceCube::Schedule.new(dtstart, { duration: duration.to_i }) do |s|
      s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(dtstart.hour).until(dtend))
    end

    content = create_content_dummy({ event_schedule: [schedule] })
    start_date = subject.start_date(virtual_parameters: ['event_schedule'], virtual_definition: { 'type' => 'datetime', 'virtual' => { 'parameters' => ['event_schedule'] } }, content:)

    assert_equal(dtstart, start_date)
  end
end

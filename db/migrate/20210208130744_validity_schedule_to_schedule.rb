# frozen_string_literal: true

class ValidityScheduleToSchedule < ActiveRecord::Migration[5.2]
  def up
    # trash all 101-1231
    DataCycleCore::Schedule.where(rrule: 'FREQ=YEARLY;BYYEARDAY=1,365', relation: 'validity_schedule').delete_all

    # transform everything else to schedule
    DataCycleCore::Schedule.where(duration: nil, relation: 'validity_schedule').find_each do |schedule|
      from_date, to_date = schedule.schedule_object.first(2)
      to_date += 1.year if from_date > to_date
      from_yday = from_date.in_time_zone.to_date.yday
      to_yday = to_date.in_time_zone.to_date.yday
      to_yday = -366 + to_yday if from_yday > to_yday
      rrule = IceCube::Rule.yearly.day_of_year(from_yday, to_yday)
      options = { end_time: to_date.in_time_zone.end_of_day }
      new_schedule_object = IceCube::Schedule.new(from_date.in_time_zone, options) do |s|
        s.add_recurrence_rule(rrule)
      end

      schedule.from_hash(new_schedule_object.to_hash.merge(dtstart: from_date.in_time_zone))
      schedule.save!
    end
  end

  def down
  end
end

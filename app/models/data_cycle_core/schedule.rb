# frozen_string_literal: true

module DataCycleCore
  module ScheduleHandler
    attr_accessor :schedule_object

    def to_h
      @schedule_object.to_hash
    end

    def from_hash(hash)
      @schedule_object = IceCube::Schedule.from_hash(hash)
    end

    def to_s
      "#{@schedule_object} (#{dtstart&.to_s(:only_date)} - #{dtend&.to_s(:only_date)} // #{dtstart&.to_s(:only_time)} - #{dtend&.to_s(:only_time)})"
    end

    def load_schedule_object
      @schedule_object = IceCube::Schedule.new(dtstart.presence || Time.zone.now, { end_time: dtend.present? }.compact.presence) do |s|
        s.add_recurrence_rule(IceCube::Rule.from_ical(rrule)) if rrule.present? # allow only one rrule!!
        rdate.each do |rd|
          s.add_recurrence_time(rd)
        end
        exdate.each do |exd|
          s.add_exception_time(exd)
        end
        s.duration = duration.to_i
      end
    end

    def serialize_schedule_object
      return if @schedule_object.blank?
      self.rrule = @schedule_object.recurrence_rules&.first&.to_ical
      self.dtstart = @schedule_object.start_time
      self.duration = ActiveSupport::Duration.build(@schedule_object.duration)
      self.dtend = @schedule_object.recurrence_rules&.first&.until_time&.in_time_zone
      self.rdate = @schedule_object.recurrence_times
      self.exdate = @schedule_object.extimes
      self.duration = ActiveSupport::Duration.build(@schedule_object.duration)
    end
  end

  class Schedule < ApplicationRecord
    class History < ApplicationRecord
      include DataCycleCore::ScheduleHandler
      belongs_to :thing_history, class_name: 'DataCycleCore::Thing::History'
      belongs_to :external_source
      after_find :load_schedule_object
      before_save :serialize_schedule_object
    end

    include DataCycleCore::ScheduleHandler
    belongs_to :thing
    belongs_to :external_source
    after_find :load_schedule_object
    before_save :serialize_schedule_object

    attr_accessor :schedule_object

    # SELECT *
    # FROM schedules
    # WHERE
    # tstzrange('2010-01-01 00:00:00+02'::timestamp with time zone - duration, '2020-12-31 00:00:00+02'::timestamp with time zone, '[]') && tstzrange(dtstart, dtend, '[]')
    # AND
    # tstzrange('2010-01-01 00:00:00+02'::timestamp with time zone - duration, '2020-12-31 00:00:00+02'::timestamp with time zone, '[]') @> ANY (
    # SELECT event_date from unnest(rdate) AS event_date
    # UNION
    # SELECT event_date FROM unnest(get_occurrences(rrule::rrule, dtstart)) AS event_date
    # EXCEPT
    # SELECT event_date from unnest(exdate) AS event_date
    # )
  end
end

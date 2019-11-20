# frozen_string_literal: true

module DataCycleCore
  class Schedule < ApplicationRecord
    belongs_to :external_sources
    after_find :load_schedule_object
    before_save :serialize_schedule_object

    attr_accessor :schedule_object

    # SELECT distinct schedules.*
    # FROM schedules, unnest(get_occurrences(rrule::rrule, dtstart)) AS event_date
    # WHERE '(2010-01-01 00:00:00+02, 2020-12-31 00:00:00+02)'::TSTZRANGE @> event_date AND event_date <> ALL(exdate)

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

    def to_h
      @schedule_object.to_hash
    end

    def from_hash(hash)
      @schedule_object = IceCube::Schedule.from_hash(hash)
    end

    def to_s
      "#{@schedule_object} (#{dtstart&.to_s(:only_date)} - #{dtend&.to_s(:only_date)})"
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
      self.dtend = @schedule_object.recurrence_rules&.first&.until_time
      self.rdate = @schedule_object.recurrence_times
      self.exdate = @schedule_object.extimes
      self.duration = ActiveSupport::Duration.build(@schedule_object.duration)
    end
  end
end

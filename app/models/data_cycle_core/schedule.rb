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

    def to_h
      @schedule_object.to_hash
    end

    def load_schedule_object
      @schedule_object = IceCube::Schedule.new(dtstart.presence || Time.zone.now, { end_time: dtend.present? }.compact.presence) do |s|
        s.add_recurrence_rule(IceCube::Rule.from_ical(rrule)) if rrule.present? # allow only one rrule!!
        exdate.each do |exd|
          s.add_exception_time(exd)
        end
      end
    end

    def serialize_schedule_object
      return if @schedule_object.blank?
      self.rrule = @schedule_object.recurrence_rules&.first&.to_ical
      self.dtstart = @schedule_object.start_time
      self.dtend = @schedule_object.end_time
      self.exdate = @schedule_object.extimes
    end
  end
end

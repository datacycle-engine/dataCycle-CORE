# frozen_string_literal: true

module DataCycleCore
  module ScheduleHandler
    def to_h
      item_hash = @schedule_object.to_hash
      item_hash[:duration] = duration
      item_hash[:id] = id
      item_hash[:relation] = relation
      item_hash[:dtstart] = dtstart if dtstart.present?
      item_hash[:dtend] = dtend if dtstart.present?
      item_hash
    end

    def from_h(hash)
      @schedule_object = nil
      @schedule_object = IceCube::Schedule.from_hash(hash) if hash.except(:id, :thing_id, :thing_history_id, :dtstart, :dtend, :relation, :duration).present?
      self.duration = hash[:duration]
      self.dtstart = hash[:dtstart]
      self.dtend = hash[:dtend]
      self.relation = hash[:relation] || relation
      serialize_schedule_object
      self
    end

    def to_s
      "#{@schedule_object} (#{dtstart&.to_s(:only_date)} - #{dtend&.to_s(:only_date)} // #{dtstart&.to_s(:only_time)} - #{(dtstart + (duration || 0))&.to_s(:only_time)})"
    end

    def dow(day)
      {
        1 => 'http://schema.org/Monday',
        2 => 'http://schema.org/Tuesday',
        3 => 'http://schema.org/Wednesday',
        4 => 'http://schema.org/Thursday',
        5 => 'http://schema.org/Friday',
        6 => 'http://schema.org/Saturday',
        0 => 'http://schema.org/Sunday'
      }[day]
    end

    def to_schedule_schema_org
      # supports only select features of the rrule spec https://github.com/schemaorg/schemaorg/issues/1457
      end_time = dtend&.to_s(:only_time)
      end_time = (dtstart + duration)&.to_s(:only_time) if dtstart.present? && duration.present?
      repeat_count = nil
      repeat_frequency = nil
      by_day = nil
      by_month = nil
      by_month_day = nil
      if @schedule_object&.recurrence_rules&.first.present?
        rule = @schedule_object&.recurrence_rules&.first
        rule_ical = rule.to_ical
        rule_hash = rule.to_hash
        end_time = rule&.until_time&.in_time_zone&.to_s(:only_time) if end_time.blank? && rule&.until_time.present?
        repeat_count = rule&.occurrence_count
        repeat_frequency = /FREQ=(.+?);/.match(rule_ical).try(:send, '[]', 1)&.downcase&.presence
        by_day = rule_hash.dig(:validations, :day)
        by_month = rule_hash.dig(:validations, :month_of_year)
        by_month_day = rule_hash.dig(:validations, :day_of_month)
      end

      {
        'startDate' => dtstart&.to_s(:only_date),
        'endDate' => dtend&.to_s(:only_date),
        'startTime' => dtstart&.to_s(:only_time),
        'endTime' => end_time,
        'duration' => duration&.iso8601,
        'repeatCount' => repeat_count,
        'exceptDate' => exdate&.map(&:to_s)&.presence,
        'additionalDate' => rdate&.map(&:to_s)&.presence,
        'repeatFrequency' => repeat_frequency,
        'byDay' => by_day&.map { |day| dow(day) },
        'byMonth' => by_month&.map(&:to_i),
        'byMonthDay' => by_month_day&.map(&:to_i)
      }.compact
    end

    def load_schedule_object
      options = { duration: duration.presence&.to_i }.compact
      @schedule_object = IceCube::Schedule.new(dtstart.presence || Time.zone.now, options) do |s|
        s.add_recurrence_rule(IceCube::Rule.from_ical(rrule)) if rrule.present? # allow only one rrule!!
        rdate.each do |rd|
          s.add_recurrence_time(rd)
        end
        exdate.each do |exd|
          s.add_exception_time(exd)
        end
      end
    end

    def serialize_schedule_object
      return if @schedule_object.blank?
      self.rrule = @schedule_object.recurrence_rules&.first&.to_ical
      self.dtstart = @schedule_object.start_time
      self.duration = ActiveSupport::Duration.build(@schedule_object.duration) if @schedule_object.duration.positive?
      self.dtend = @schedule_object.recurrence_rules&.first&.until_time&.in_time_zone || (@schedule_object.start_time + duration)
      self.rdate = @schedule_object.recurrence_times
      self.exdate = @schedule_object.extimes
      self
    end

    def occurs_between?(from = dtstart, to = dtend)
      @schedule_object.occurs_between?(from, to, spans: true) # consider also overlap of [from, to] with [starttime, starttime + duration]
    end
  end

  class Schedule < ApplicationRecord
    class History < ApplicationRecord
      include ScheduleHandler
      belongs_to :thing_history, class_name: 'DataCycleCore::Thing::History'
      belongs_to :external_source
      after_find :load_schedule_object
      before_save :serialize_schedule_object

      attr_accessor :schedule_object

      def history?
        true
      end

      def to_h
        super.merge(thing_history_id: thing_history_id)
      end
      alias to_hash to_h

      def from_h(hash)
        self.thing_history_id = hash[:thing_history_id] || thing_history_id
        super
      end
      alias from_hash from_h
    end

    include ScheduleHandler
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

    def history?
      false
    end

    def to_h
      super.merge(thing_id: thing_id)
    end
    alias to_hash to_h

    def from_h(hash)
      self.thing_id = hash[:thing_id] || thing_id
      super
    end
    alias from_hash from_h
  end
end

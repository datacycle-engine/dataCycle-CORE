# frozen_string_literal: true

module DataCycleCore
  module ScheduleHandler
    DAY_OF_WEEK_MAPPING = {
      1 => 'https://schema.org/Monday',
      2 => 'https://schema.org/Tuesday',
      3 => 'https://schema.org/Wednesday',
      4 => 'https://schema.org/Thursday',
      5 => 'https://schema.org/Friday',
      6 => 'https://schema.org/Saturday',
      0 => 'https://schema.org/Sunday',
      99 => 'https://schema.org/PublicHolidays'
    }.freeze

    def self.included(klass)
      klass.extend(ClassMethods)
    end

    def to_h
      item_hash = @schedule_object&.to_hash || {}
      item_hash[:duration] = duration
      item_hash[:id] = id
      item_hash[:relation] = relation
      item_hash[:dtstart] = dtstart if dtstart.present?
      item_hash[:dtend] = dtend if dtstart.present?
      item_hash[:holidays] = holidays
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
      DAY_OF_WEEK_MAPPING[day]
    end

    def to_repeat_frequency(rule_hash)
      return if rule_hash[:interval].nil? || rule_hash[:rule_type].nil?

      interval = rule_hash.dig(:interval).to_s

      case rule_hash.dig(:rule_type)
      when 'IceCube::YearlyRule'
        "P#{interval}Y"
      when 'IceCube::MonthlyRule'
        "P#{interval}M"
      when 'IceCube::WeeklyRule'
        "P#{interval}W"
      when 'IceCube::DailyRule'
        "P#{interval}D"
      end
    end

    def to_api_default_values
      {
        '@id' => id,
        '@type' => 'Schedule'
      }
    end

    def to_opening_hours_specification_schema_org
      rule = @schedule_object&.recurrence_rules&.first
      rule_hash = rule&.to_hash

      {
        '@type' => 'OpeningHoursSpecification',
        'validFrom' => @schedule_object&.start_time&.in_time_zone&.to_s(:only_date),
        'validThrough' => rule_hash&.dig(:until)&.in_time_zone&.to_s(:only_date),
        'opens' => dtstart&.to_s(:only_time),
        'closes' => dtend&.to_s(:only_time),
        'dayOfWeek' => Array.wrap(rule_hash&.dig(:validations, :day)&.map { |day| dow(day) }).concat(holidays ? [dow(99)] : []).presence
      }.compact
    end

    def to_opening_hours_specification_schema_org_api_v3
      to_opening_hours_specification_schema_org&.merge({
        'contentType' => 'Öffnungszeit',
        '@context' => 'http://schema.org'
      })
    end

    def to_schedule_schema_org
      # supports only select features of the rrule spec https://github.com/schemaorg/schemaorg/issues/1457
      start_date = dtstart&.to_s(:only_date)
      start_time = dtstart&.to_s(:only_time)
      end_date = nil
      end_time = nil
      repeat_count = nil
      repeat_frequency = nil
      by_day = nil
      by_month = nil
      by_month_day = nil
      iso_duration = @schedule_object.duration.present? && @schedule_object.start_time && @schedule_object.end_time ? iso8601_duration(@schedule_object.start_time, @schedule_object.end_time) : nil
      if @schedule_object&.recurrence_rules&.first.present?
        rule = @schedule_object&.recurrence_rules&.first
        rule_hash = rule.to_hash
        end_date = @schedule_object&.last&.in_time_zone&.+(@schedule_object&.duration&.presence || 0)&.to_s(:only_date) if end_date.blank? && @schedule_object.terminating?
        end_time = @schedule_object&.last&.in_time_zone&.+(@schedule_object&.duration&.presence || 0)&.to_s(:only_time) if end_time.blank? && @schedule_object.terminating?
        repeat_count = rule&.occurrence_count
        repeat_frequency = to_repeat_frequency(rule_hash)
        by_day = rule_hash.dig(:validations, :day)
        by_month = rule_hash.dig(:validations, :month_of_year)
        by_month_day = rule_hash.dig(:validations, :day_of_month)
      end

      {
        '@context' => 'https://schema.org/',
        '@type' => 'Schedule',
        'inLanguage' => I18n.locale.to_s,
        'startDate' => start_date,
        'endDate' => end_date,
        'startTime' => start_time,
        'endTime' => end_time,
        'duration' => iso_duration,
        'repeatCount' => repeat_count,
        'exceptDate' => exdate&.map(&:iso8601)&.presence,
        'dc:additionalDate' => rdate&.map(&:iso8601)&.presence,
        'repeatFrequency' => repeat_frequency,
        'byDay' => by_day&.map { |day| dow(day) },
        'byMonth' => by_month&.map(&:to_i),
        'byMonthDay' => by_month_day&.map(&:to_i),
        'scheduleTimezone' => dtstart.time_zone.name
      }.compact
    end

    def to_schedule_schema_org_api_v3
      return {} unless @schedule_object.terminating?
      return {} unless @schedule_object.all_occurrences.size.positive?
      start_date = dtstart&.beginning_of_day&.to_s(:long_msec)
      start_time = dtstart&.to_s(:only_time)
      end_date = nil
      end_time = nil
      repeat_count = nil
      repeat_frequency = nil
      by_day = nil
      by_month = nil
      by_month_day = nil
      iso_duration = @schedule_object.duration.present? && @schedule_object.start_time && @schedule_object.end_time ? iso8601_duration(@schedule_object.start_time, @schedule_object.end_time) : nil
      if @schedule_object&.recurrence_rules&.first.present?
        rule = @schedule_object&.recurrence_rules&.first
        rule_ical = rule.to_ical
        rule_hash = rule.to_hash
        end_date = @schedule_object&.last&.in_time_zone&.+(@schedule_object&.duration&.presence || 0)&.beginning_of_day&.to_s(:long_msec) if end_date.blank? && @schedule_object.terminating?
        end_time = @schedule_object&.last&.in_time_zone&.+(@schedule_object&.duration&.presence || 0)&.to_s(:only_time) if end_time.blank? && @schedule_object.terminating?
        repeat_count = rule&.occurrence_count
        repeat_frequency = /FREQ=(.+?);/.match(rule_ical).try(:send, '[]', 1)&.downcase&.presence
        by_day = rule_hash.dig(:validations, :day)
        by_month = rule_hash.dig(:validations, :month_of_year)
        by_month_day = rule_hash.dig(:validations, :day_of_month)
      end

      schedule_hash = {
        '@context' => 'http://schema.org',
        '@type' => 'Schedule',
        'contentType' => 'EventSchedule',
        'inLanguage' => I18n.locale.to_s,
        'startDate' => start_date,
        'endDate' => end_date,
        'startTime' => start_time,
        'endTime' => end_time,
        'duration' => iso_duration,
        'repeatCount' => repeat_count,
        'exceptDate' => exdate&.map(&:to_s)&.presence,
        'additionalDate' => rdate&.map(&:to_s)&.presence,
        'repeatFrequency' => repeat_frequency,
        'byDay' => by_day&.map { |day| dow(day) },
        'byMonth' => by_month&.map(&:to_i),
        'byMonthDay' => by_month_day&.map(&:to_i)
      }.compact

      schedule_hash.merge({ 'identifier' => generate_uuid(schedule_hash) })
    end

    def to_schedule_schema_org_api_v2
      return {} unless @schedule_object.terminating?
      return {} unless @schedule_object.all_occurrences.size.positive?
      start_date = dtstart&.beginning_of_day&.to_s(:long_msec)
      start_time = dtstart&.to_s(:only_time)
      end_date = nil
      end_time = nil
      repeat_count = nil
      repeat_frequency = nil
      by_day = nil
      by_month = nil
      by_month_day = nil
      iso_duration = @schedule_object.duration.present? && @schedule_object.start_time && @schedule_object.end_time ? iso8601_duration(@schedule_object.start_time, @schedule_object.end_time) : nil
      if @schedule_object&.recurrence_rules&.first.present?
        rule = @schedule_object&.recurrence_rules&.first
        rule_hash = rule.to_hash
        end_date = @schedule_object&.last&.in_time_zone&.+(@schedule_object&.duration&.presence || 0)&.beginning_of_day&.to_s(:long_msec) if end_date.blank? && @schedule_object.terminating?
        end_time = @schedule_object&.last&.in_time_zone&.+(@schedule_object&.duration&.presence || 0)&.to_s(:only_time) if end_time.blank? && @schedule_object.terminating?
        by_day = rule_hash.dig(:validations, :day)
        by_month = rule_hash.dig(:validations, :month_of_year)
        by_month_day = rule_hash.dig(:validations, :day_of_month)
      end

      {
        '@context' => 'http://schema.org',
        '@type' => 'Schedule',
        'contentType' => 'EventSchedule',
        'startDate' => start_date,
        'endDate' => end_date,
        'startTime' => start_time,
        'endTime' => end_time,
        'duration' => iso_duration,
        'repeatCount' => repeat_count,
        'exceptDate' => exdate&.map(&:to_s)&.presence,
        'additionalDate' => rdate&.map(&:to_s)&.presence,
        'repeatFrequency' => repeat_frequency,
        'by_day' => by_day&.map { |day| dow(day) },
        'by_month' => by_month&.map(&:to_i),
        'by_month_day' => by_month_day&.map(&:to_i)
      }.compact
    end

    def to_sub_event_api_v2
      return [] unless @schedule_object.terminating?
      @schedule_object.all_occurrences.map do |occurrence|
        {
          '@context' => 'http://schema.org',
          '@type' => 'Event',
          'contentType' => 'SubEvent',
          'startDate' => occurrence.start_time&.to_s(:long_msec),
          'endDate' => occurrence.end_time&.to_s(:long_msec)
        }
      end
    end

    def to_sub_event
      return [] unless @schedule_object.terminating?
      @schedule_object.all_occurrences.map do |occurrence|
        sub_event_hash = {
          '@context' => 'http://schema.org',
          '@type' => 'Event',
          'contentType' => 'SubEvent',
          'inLanguage' => I18n.locale.to_s,
          'startDate' => occurrence.start_time.to_s(:long_msec),
          'endDate' => occurrence.end_time.to_s(:long_msec)
        }
        sub_event_hash.merge({ 'identifier' => generate_uuid(sub_event_hash) })
      end
    end

    def to_event_dates
      return [] if @schedule_object.blank?
      if @schedule_object.terminating?
        @schedule_object.all_occurrences.to_a.map { |o| o.start_time.to_s(:long_msec) }
      else
        @schedule_object.next_occurrences(10).to_a.map { |o| o.start_time.to_s(:long_msec) }
      end
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
      self.duration = @schedule_object.duration if @schedule_object.duration.positive?
      self.dtend = @schedule_object.terminating? ? (@schedule_object.last || @schedule_object.start_time) + (duration || 0) : nil
      self.rdate = @schedule_object.recurrence_times
      self.exdate = @schedule_object.extimes
      self
    end

    def iso8601_duration(start_time, end_time)
      time_hash = distance_of_time_in_words_hash(start_time, end_time)
      return 'PT0S' if time_hash.empty?

      output = +'P'
      output << "#{time_hash[:years]}Y" if time_hash[:years]&.positive?
      output << "#{time_hash[:months]}M" if time_hash[:months]&.positive?
      output << "#{(time_hash[:weeks] || 0) * 7 + (time_hash[:days] || 0)}D" if time_hash[:weeks]&.positive? || time_hash[:days]&.positive?
      if time_hash[:seconds]&.positive? || time_hash[:minutes]&.positive? || time_hash[:hours]&.positive?
        output << 'T'
        output << "#{time_hash[:hours]}H" if time_hash[:hours]&.positive?
        output << "#{time_hash[:minutes]}M" if time_hash[:minutes]&.positive?
        output << "#{time_hash[:seconds]}S" if time_hash[:seconds]&.positive?
      end

      output
    end

    def occurs_between?(from = dtstart, to = dtend)
      @schedule_object.occurs_between?(from, to, spans: true) # consider also overlap of [from, to] with [starttime, starttime + duration]
    end

    def generate_uuid(data_hash)
      uuid = Digest::MD5.hexdigest(data_hash.to_s)
      [uuid[0..7], '-', uuid[8..11], '-', uuid[12..15], '-', uuid[16..19], '-', uuid[20..32]].join
    end

    module ClassMethods
      def to_h_from_schedule_params(value)
        return nil if value.blank? || value.values.blank?

        value.values.map { |s|
          next nil if s.dig('start_time', 'time').blank?

          start_time = s.dig('start_time', 'time')&.in_time_zone
          end_time = s.dig('end_time', 'time')&.in_time_zone
          end_time ||= start_time if s.dig('yearly_end').blank?

          if s['full_day'] == '1'
            start_time = start_time.beginning_of_day
            s['duration'] = (end_time.beginning_of_day - start_time.beginning_of_day) + 1.day
          elsif end_time.present?
            s['duration'] = time_to_duration(start_time.strftime('%H:%M'), end_time.strftime('%H:%M'))
          end

          s['start_time'] = {
            time: start_time.to_s,
            zone: start_time.time_zone.name
          }

          s['rrules'][0]['until'] = s.dig('rrules', 0, 'until').in_time_zone.end_of_day if s.dig('rrules', 0, 'until').present?
          s['rrules'][0]['validations'] ||= {}
          s['rrules'][0]['validations']['hour_of_day'] = [start_time.to_datetime.hour] if s.dig('rrules', 0).present? && s.dig('yearly_end').blank?
          s['rrules'][0]['validations']['minute_of_hour'] = [start_time.to_datetime.minute] if s.dig('rrules', 0).present? && start_time.to_datetime.minute.positive?
          s['rtimes'] = s['rtimes'].presence&.split(',')&.map { |t| { time: "#{t.strip} #{start_time.to_s(:time)}".in_time_zone, zone: start_time.time_zone.name } }
          s['extimes'] = s['extimes'].presence&.split(',')&.map { |t| { time: "#{t.strip} #{start_time.to_s(:time)}".in_time_zone, zone: start_time.time_zone.name } }

          case s.dig('rrules', 0, 'rule_type')
          when 'IceCube::WeeklyRule'
            s.dig('rrules', 0, 'validations', 'day')&.map!(&:to_i)
          when 'IceCube::SingleOccurrenceRule'
            s.except!('rrules')
          when 'IceCube::YearlyRule'
            from_yday = start_time&.to_date&.yday
            to_yday = s.dig('yearly_end', 'time')&.to_date&.yday
            if to_yday.present?
              to_yday = -366 + to_yday if from_yday > to_yday
              s['rrules'][0]['validations']['day_of_year'] = [from_yday, to_yday]
            else
              s.dig('rrules', 0, 'validations')&.delete('day')
            end
          else
            s.dig('rrules', 0, 'validations')&.delete('day')
          end

          DataCycleCore::Schedule.new.from_hash(s.slice('id', 'start_time', 'duration', 'rrules', 'rtimes', 'extimes').deep_reject { |_, v| v.blank? }).to_hash.except(:relation, :thing_id).merge(id: s['id']).deep_stringify_keys.compact
        }.compact
      end

      def to_h_from_opening_time_params(value)
        return if value.blank? || value.values.blank?

        value.values.map { |s|
          next unless s&.dig('time').present? && s['time'].values.present? && s['valid_from'].present? && (s.dig('rrules', 0, 'validations', 'day').present? || s['holiday'] == 'true')

          s['time'].values.map do |t|
            next if t.blank? || t['opens'].blank? || t['closes'].blank?

            start_time = "#{s['valid_from']} #{t['opens']}".in_time_zone
            duration = time_to_duration(t['opens'], t['closes'])
            days = Array.wrap(s.dig('rrules', 0, 'validations', 'day')).map(&:to_i)

            if s['valid_until'].present? && ((s['holiday'] == 'true' && (0...7).to_a.difference(days).present?) || s['holiday'] == 'false')
              holidays = Holidays
                .between(start_time, s['valid_until'].in_time_zone.end_of_day, Array.wrap(DataCycleCore.holidays_country_code))
                .map { |d| { time: "#{d[:date]} #{start_time.to_s(:time)}".in_time_zone, zone: start_time.time_zone.name } }
            end

            {
              id: t['id'],
              start_time: {
                time: start_time.to_s,
                zone: start_time.time_zone.name
              },
              holidays: s['holiday'] == 'ignore' ? nil : s['holiday'] == 'true',
              duration: duration,
              rtimes: s['holiday'] == 'true' ? holidays : nil,
              extimes: s['holiday'] == 'false' ? holidays : nil,
              rrules: [{
                rule_type: 'IceCube::WeeklyRule',
                validations: {
                  day: days
                },
                until: s['valid_until']&.in_time_zone&.end_of_day
              }]
            }.deep_reject { |_, v| v.blank? && !v.is_a?(FalseClass) }.with_indifferent_access
          end
        }.flatten.compact
      end

      def time_to_duration(start_time, end_time)
        return 0 if start_time.blank? || end_time.blank?

        start_time = start_time.to_datetime
        end_time = end_time.to_datetime
        end_time += 1.day if end_time < start_time

        ((end_time - start_time) * 24 * 60 * 60).to_i
      end
    end
  end

  class Schedule < ApplicationRecord
    require 'dotiw'

    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::NumberHelper

    class History < ApplicationRecord
      include ScheduleHandler
      belongs_to :thing_history, class_name: 'DataCycleCore::Thing::History'
      belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'
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
    belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'
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

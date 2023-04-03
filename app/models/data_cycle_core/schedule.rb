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
      klass.extend(DOTIW::Methods)
    end

    delegate :iso8601_duration, to: :class
    delegate :parse_iso8601_duration, to: :class

    def to_h
      item_hash = @schedule_object&.to_hash || {}
      item_hash[:duration] = duration.iso8601 if duration&.positive?
      item_hash[:id] = id
      item_hash[:relation] = relation
      item_hash[:dtstart] = dtstart if dtstart.present?
      item_hash[:dtend] = dtend if dtstart.present?
      item_hash[:holidays] = holidays unless holidays.nil?
      item_hash[:external_key] = external_key if external_key.present?
      item_hash[:external_source_id] = external_source_id if external_source_id.present?
      item_hash
    end

    def from_h(hash)
      @schedule_object = nil
      hash = hash.with_indifferent_access
      hash[:duration] = parse_iso8601_duration(hash[:duration]) if hash.key?(:duration)
      if hash.except(:id, :thing_id, :thing_history_id, :dtstart, :dtend, :relation, :duration).present?
        @schedule_object = IceCube::Schedule.from_hash(
          hash.deep_dup.tap do |h|
            h[:end_time] = h.dig(:start_time, :time).in_time_zone(h.dig(:start_time, :zone))&.advance(h.delete(:duration)&.parts.to_h) if h.key?(:duration)
          end
        )
      end

      self.duration = hash[:duration]&.iso8601
      self.dtstart = hash[:dtstart]
      self.dtend = hash[:dtend]
      self.holidays = hash[:holidays]
      self.relation = hash[:relation] || relation
      self.external_key = hash[:external_key]
      self.external_source_id = hash[:external_source_id]
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
        '@id' => id,
        '@type' => 'OpeningHoursSpecification',
        'validFrom' => dtstart&.to_s(:only_date),
        'validThrough' => rule_hash&.dig(:until)&.to_s(:only_date),
        'opens' => dtstart&.to_s(:only_time),
        'closes' => dtend&.to_s(:only_time),
        'dayOfWeek' => Array.wrap(rule_hash&.dig(:validations, :day)&.map { |day| dow(day) }).concat(holidays ? [dow(99)] : []).presence
      }.compact
    end

    def to_opening_hours_specification_schema_org_api_v3
      to_opening_hours_specification_schema_org&.merge({
        'contentType' => 'Öffnungszeit',
        '@context' => 'http://schema.org'
      })&.except('@id')
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
      by_month_week = nil
      if @schedule_object&.recurrence_rules&.first.present?
        rule = @schedule_object&.recurrence_rules&.first
        rule_hash = rule.to_hash
        end_date = @schedule_object&.last&.in_time_zone&.+(duration&.presence || 0)&.to_s(:only_date) if end_date.blank? && @schedule_object.terminating?
        end_time = @schedule_object&.last&.in_time_zone&.+(duration&.presence || 0)&.to_s(:only_time) if end_time.blank? && @schedule_object.terminating?
        repeat_count = rule&.occurrence_count
        repeat_frequency = to_repeat_frequency(rule_hash)
        by_day = rule_hash.dig(:validations, :day)&.map { |day| dow(day) }
        by_month = rule_hash.dig(:validations, :month_of_year)
        by_month_day = rule_hash.dig(:validations, :day_of_month)
        if rule_hash.dig(:validations, :day_of_week).present?
          by_day = dow(rule_hash.dig(:validations, :day_of_week).keys.first)
          by_month_week = rule_hash.dig(:validations, :day_of_week).values.flatten.first
        end
      end

      {
        '@context' => 'https://schema.org/',
        '@id' => id,
        '@type' => 'Schedule',
        'inLanguage' => I18n.locale.to_s,
        'startDate' => start_date,
        'endDate' => end_date,
        'startTime' => start_time,
        'endTime' => end_time,
        'duration' => duration&.positive? ? duration.iso8601 : nil,
        'repeatCount' => repeat_count,
        'exceptDate' => exdate&.map(&:iso8601)&.presence,
        'dc:additionalDate' => rdate&.map(&:iso8601)&.presence,
        'repeatFrequency' => repeat_frequency,
        'byDay' => by_day,
        'byMonth' => by_month&.map(&:to_i),
        'byMonthDay' => by_month_day&.map(&:to_i),
        'byMonthWeek' => by_month_week,
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
      if @schedule_object&.recurrence_rules&.first.present?
        rule = @schedule_object&.recurrence_rules&.first
        rule_ical = rule.to_ical
        rule_hash = rule.to_hash
        end_date = @schedule_object&.last&.in_time_zone&.+(duration&.presence || 0)&.beginning_of_day&.to_s(:long_msec) if end_date.blank? && @schedule_object.terminating?
        end_time = @schedule_object&.last&.in_time_zone&.+(duration&.presence || 0)&.to_s(:only_time) if end_time.blank? && @schedule_object.terminating?
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
        'duration' => duration&.positive? ? duration.iso8601 : nil,
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
      if @schedule_object&.recurrence_rules&.first.present?
        rule = @schedule_object&.recurrence_rules&.first
        rule_hash = rule.to_hash
        end_date = @schedule_object&.last&.in_time_zone&.+(duration&.presence || 0)&.beginning_of_day&.to_s(:long_msec) if end_date.blank? && @schedule_object.terminating?
        end_time = @schedule_object&.last&.in_time_zone&.+(duration&.presence || 0)&.to_s(:only_time) if end_time.blank? && @schedule_object.terminating?
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
        'duration' => duration&.positive? ? duration.iso8601 : nil,
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

    def to_ical_string_api_v4
      {
        'dc:ical' => schedule_object&.to_ical
      }.compact
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
      options = { duration: duration.presence }.compact

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
      self.duration ||= iso8601_duration(@schedule_object.start_time, @schedule_object.end_time)&.iso8601
      self.dtend = @schedule_object.terminating? ? (@schedule_object.last || @schedule_object.start_time) + (duration || 0) : nil
      self.rdate = @schedule_object.recurrence_times
      self.exdate = @schedule_object.extimes
      self
    end

    def occurs_between?(from = dtstart, to = dtend)
      @schedule_object.occurs_between?(from, to, spans: true) # consider also overlap of [from, to] with [starttime, starttime + duration]
    end

    def generate_uuid(data_hash)
      uuid = Digest::MD5.hexdigest(data_hash.to_s)
      [uuid[0..7], '-', uuid[8..11], '-', uuid[12..15], '-', uuid[16..19], '-', uuid[20..32]].join
    end

    module ClassMethods
      def until_as_utc_iso8601(until_date, until_time)
        return if until_date.blank? || until_time.blank?

        "#{until_date.in_time_zone.to_date.iso8601}T#{until_time.in_time_zone.strftime('%T')}+00:00"
      end

      def to_h_from_schedule_params(value)
        return nil if value.blank? || value.values.blank?

        value.values.map { |s|
          s = s['datahash'] if s.key?('datahash')
          next nil if s.dig('start_time', 'time').blank?

          start_time = s.dig('start_time', 'time')&.in_time_zone

          s['duration'] = parts_to_iso8601_duration(s['duration']).iso8601
          s['start_time'] = {
            time: start_time.to_s,
            zone: start_time.time_zone.name
          }

          s['rrules'][0]['until'] = until_as_utc_iso8601(s.dig('rrules', 0, 'until'), start_time) if s.dig('rrules', 0, 'until').present?
          s['rrules'][0]['validations'] ||= {}
          s['rrules'][0]['validations']['hour_of_day'] = [start_time.to_datetime.hour] if s.dig('rrules', 0).present?
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

            s['rrules'][0]['validations']['day_of_year'] = [from_yday]
            s.dig('rrules', 0, 'validations')&.delete('day')
          else
            s.dig('rrules', 0, 'validations')&.delete('day')
          end

          DataCycleCore::Schedule.new.from_hash(s.slice('id', 'start_time', 'duration', 'rrules', 'rtimes', 'extimes').deep_reject { |_, v| DataCycleCore::DataHashService.blank?(v) }.with_indifferent_access).to_hash.except(:relation, :thing_id).merge(id: s['id']).with_indifferent_access.compact
        }.compact
      end

      def to_h_from_opening_time_params(value)
        return if value.blank? || value.values.blank?

        value.values.map { |s|
          s = s['datahash'] if s.key?('datahash')
          next unless s&.dig('time').present? && s['time'].values.present? && s['valid_from'].present? && (s.dig('rrules', 0, 'validations', 'day').present? || s['holiday'] == 'true')

          s['time'].values.map do |t|
            t = t['datahash'] if t.key?('datahash')
            next if t.blank? || t['opens'].blank? || t['closes'].blank?

            start_time = "#{s['valid_from']} #{t['opens']}".in_time_zone
            duration = time_to_duration(t['opens'], t['closes'])
            days = Array.wrap(s.dig('rrules', 0, 'validations', 'day')).map(&:to_i)

            if s['valid_until'].present? && ((s['holiday'] == 'true' && (0...7).to_a.difference(days).present?) || s['holiday'] == 'false')
              holidays = Holidays
                .between(start_time, s['valid_until'].in_time_zone.end_of_day, Array.wrap(DataCycleCore.holidays_country_code))
                .map { |d| { time: "#{d[:date]} #{start_time.to_s(:time)}".in_time_zone, zone: start_time.time_zone.name } }
            end

            DataCycleCore::Schedule.new.from_hash({
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
                until: until_as_utc_iso8601(s['valid_until'], t['opens'])
              }]
            }.deep_reject { |_, v| DataCycleCore::DataHashService.blank?(v) }.with_indifferent_access).to_hash.except(:relation, :thing_id).merge(id: t['id']).with_indifferent_access.compact
          end
        }.flatten.compact
      end

      def iso8601_duration(start_time, end_time)
        return if end_time.nil?

        duration_hash = distance_of_time_in_words_hash(start_time, end_time)

        parts_to_iso8601_duration(duration_hash)
      end

      # for time only
      def time_to_duration(start_time, end_time)
        return 0 if start_time.blank? || end_time.blank?

        start_time = start_time.to_datetime
        end_time = end_time.to_datetime
        end_time += 1.day if end_time < start_time

        ((end_time - start_time) * 24 * 60 * 60)
      end

      def parts_to_iso8601_duration(duration_hash)
        return ActiveSupport::Duration.build(0) if duration_hash.blank?
        return ActiveSupport::Duration.build(duration_hash.to_i) unless duration_hash.is_a?(::Hash)

        duration_hash = duration_hash.transform_values(&:to_i).with_indifferent_access

        output = +'P'
        output << "#{duration_hash[:years]}Y" if duration_hash[:years]&.positive?
        output << "#{duration_hash[:months]}M" if duration_hash[:months]&.positive?
        output << "#{((duration_hash[:weeks] || 0) * 7) + (duration_hash[:days] || 0)}D" if duration_hash[:weeks]&.positive? || duration_hash[:days]&.positive?
        if duration_hash[:seconds]&.positive? || duration_hash[:minutes]&.positive? || duration_hash[:hours]&.positive?
          output << 'T'
          output << "#{duration_hash[:hours]}H" if duration_hash[:hours]&.positive?
          output << "#{duration_hash[:minutes]}M" if duration_hash[:minutes]&.positive?
          output << "#{duration_hash[:seconds]}S" if duration_hash[:seconds]&.positive?
        end

        ActiveSupport::Duration.parse(output)
      rescue ActiveSupport::Duration::ISO8601Parser::ParsingError
        ActiveSupport::Duration.build(0)
      end

      def parse_iso8601_duration(duration_string)
        return duration_string if duration_string.is_a?(ActiveSupport::Duration)
        return ActiveSupport::Duration.build(0) if duration_string.blank?
        return ActiveSupport::Duration.build(duration_string) if duration_string.is_a?(::Numeric)

        ActiveSupport::Duration.parse(duration_string)
      end

      def iso8601_duration_to_parts(duration_string)
        duration = parse_iso8601_duration(duration_string)

        duration.present? ? duration.parts : {}
      end
    end
  end

  class Schedule < ApplicationRecord
    attribute :duration, :interval

    require 'dotiw'

    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::NumberHelper

    class History < ApplicationRecord
      attribute :duration, :interval

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

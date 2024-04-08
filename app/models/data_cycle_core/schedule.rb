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

    REPEAT_FREQUENCY_MAPPING = {
      'Y' => 'IceCube::YearlyRule',
      'M' => 'IceCube::MonthlyRule',
      'W' => 'IceCube::WeeklyRule',
      'D' => 'IceCube::DailyRule'
    }.freeze

    def self.included(klass)
      klass.extend(ClassMethods)
      klass.extend(DOTIW::Methods)
    end

    delegate :iso8601_duration, to: :class
    delegate :parse_iso8601_duration, to: :class

    def schedule_object
      return @schedule_object if defined? @schedule_object

      @schedule_object = load_schedule_object
    end

    def schedule_object=(value)
      @schedule_object = value
      reload_memoized
    end

    def reload_memoized
      remove_instance_variable(:@rrule) if instance_variable_defined?(:@rrule)
      remove_instance_variable(:@dtstart) if instance_variable_defined?(:@dtstart)
      remove_instance_variable(:@duration) if instance_variable_defined?(:@duration)
      remove_instance_variable(:@dtend) if instance_variable_defined?(:@dtend)
      remove_instance_variable(:@rdate) if instance_variable_defined?(:@rdate)
      remove_instance_variable(:@exdate) if instance_variable_defined?(:@exdate)
    end

    def rrule
      return @rrule if defined? @rrule

      @rrule = schedule_object&.recurrence_rules&.first&.to_ical
    end

    def dtstart
      return @dtstart if defined? @dtstart

      @dtstart = schedule_object&.start_time
    end

    def duration
      return @duration if defined? @duration

      if self[:duration].present?
        @duration = self[:duration]
      elsif schedule_object.present?
        @duration = iso8601_duration(schedule_object.start_time, schedule_object.end_time)
      else
        @duration = nil
      end
    end

    def dtend
      return @dtend if defined? @dtend
      return @dtend = nil if schedule_object.blank?

      @dtend = schedule_object.terminating? ? (schedule_object.last || schedule_object.start_time) + (duration || 0) : nil
    end

    def rdate
      return @rdate if defined? @rdate

      @rdate = schedule_object&.recurrence_times
    end

    def exdate
      return @exdate if defined? @exdate

      @exdate = schedule_object&.extimes
    end

    def to_h
      item_hash = schedule_object&.to_hash || {}
      item_hash[:rtimes] = nil if item_hash[:rtimes].blank?
      item_hash[:extimes] = nil if item_hash[:extimes].blank?
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
      self.schedule_object = nil
      hash = hash.with_indifferent_access
      hash[:duration] = parse_iso8601_duration(hash[:duration]) if hash.key?(:duration)
      if hash.except(:id, :thing_id, :thing_history_id, :dtstart, :dtend, :relation, :duration).present?
        self.schedule_object = IceCube::Schedule.from_hash(
          hash.deep_dup.tap do |h|
            h[:end_time] = h.dig(:start_time, :time).in_time_zone(h.dig(:start_time, :zone))&.advance(h.delete(:duration)&.parts.to_h) if h.key?(:duration)
          end
        )
      end

      self.duration = hash[:duration]
      self.dtstart = hash[:dtstart]
      self.dtend = hash[:dtend]
      self.holidays = hash[:holidays]
      self.relation = hash[:relation] || relation
      self.external_key = hash[:external_key] if hash.key?(:external_key)
      self.external_source_id = hash[:external_source_id] if hash.key?(:external_source_id)
      self
    end

    def to_s
      "#{schedule_object} (#{dtstart&.to_s(:only_date)} - #{dtend&.to_s(:only_date)} // #{dtstart&.to_s(:only_time)} - #{(dtstart + (duration || 0))&.to_s(:only_time)})"
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
      rule = schedule_object&.recurrence_rules&.first
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
      if schedule_object&.recurrence_rules&.first.present?
        rule = schedule_object&.recurrence_rules&.first
        rule_hash = rule.to_hash
        end_date = (schedule_object&.last&.in_time_zone || rule_hash.dig(:until))&.+(duration.presence || 0)&.to_s(:only_date) if end_date.blank? && schedule_object.terminating?
        end_time = schedule_object&.end_time&.to_s(:only_time) if end_time.blank? && schedule_object.terminating?
        end_time = start_time if end_date.present? && end_time.blank?
        repeat_count = rule&.occurrence_count
        repeat_frequency = to_repeat_frequency(rule_hash)
        by_day = rule_hash.dig(:validations, :day)&.map { |day| dow(day) }
        by_month = rule_hash.dig(:validations, :month_of_year)
        by_month_day = rule_hash.dig(:validations, :day_of_month)
        if rule_hash.dig(:validations, :day_of_week).present?
          by_day = dow(rule_hash.dig(:validations, :day_of_week).keys.first)
          by_month_week = rule_hash.dig(:validations, :day_of_week).values.flatten.first
        end
      else
        end_timestamp = dtstart&.+(duration.presence || 0)
        end_date = end_timestamp&.to_s(:only_date)
        end_time = end_timestamp&.to_s(:only_time)
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
      return {} unless schedule_object.terminating?
      return {} unless schedule_object.all_occurrences.size.positive?
      start_date = dtstart&.beginning_of_day&.to_s(:long_msec)
      start_time = dtstart&.to_s(:only_time)
      end_date = nil
      end_time = nil
      repeat_count = nil
      repeat_frequency = nil
      by_day = nil
      by_month = nil
      by_month_day = nil
      if schedule_object&.recurrence_rules&.first.present?
        rule = schedule_object&.recurrence_rules&.first
        rule_ical = rule.to_ical
        rule_hash = rule.to_hash
        end_date = schedule_object&.last&.in_time_zone&.+(duration.presence || 0)&.beginning_of_day&.to_s(:long_msec) if end_date.blank? && schedule_object.terminating?
        end_time = schedule_object&.last&.in_time_zone&.+(duration.presence || 0)&.to_s(:only_time) if end_time.blank? && schedule_object.terminating?
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
      return {} unless schedule_object.terminating?
      return {} unless schedule_object.all_occurrences.size.positive?
      start_date = dtstart&.beginning_of_day&.to_s(:long_msec)
      start_time = dtstart&.to_s(:only_time)
      end_date = nil
      end_time = nil
      repeat_count = nil
      repeat_frequency = nil
      by_day = nil
      by_month = nil
      by_month_day = nil
      if schedule_object&.recurrence_rules&.first.present?
        rule = schedule_object&.recurrence_rules&.first
        rule_hash = rule.to_hash
        end_date = schedule_object&.last&.in_time_zone&.+(duration.presence || 0)&.beginning_of_day&.to_s(:long_msec) if end_date.blank? && schedule_object.terminating?
        end_time = schedule_object&.last&.in_time_zone&.+(duration.presence || 0)&.to_s(:only_time) if end_time.blank? && schedule_object.terminating?
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
      return [] unless schedule_object.terminating?
      schedule_object.all_occurrences.map do |occurrence|
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
      return [] unless schedule_object.terminating?
      schedule_object.all_occurrences.map do |occurrence|
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
      return [] if schedule_object.blank?
      if schedule_object.terminating?
        schedule_object.all_occurrences.to_a.map { |o| o.start_time.to_s(:long_msec) }
      else
        schedule_object.next_occurrences(10).to_a.map { |o| o.start_time.to_s(:long_msec) }
      end
    end

    def load_schedule_object
      options = { duration: self[:duration].presence }

      IceCube::Schedule.new(self[:dtstart].presence || Time.zone.now, options) do |s|
        s.add_recurrence_rule(IceCube::Rule.from_ical(self[:rrule])) if self[:rrule].present? # allow only one rrule!!
        self[:rdate].each do |rd|
          s.add_recurrence_time(rd)
        end
        self[:exdate].each do |exd|
          s.add_exception_time(exd)
        end
      end
    end

    def serialize_schedule_object
      self.rrule = rrule
      self.dtstart = dtstart
      self.duration = duration
      self.dtend = dtend
      self.rdate = rdate
      self.exdate = exdate
      self
    end

    def occurs_between?(from = dtstart, to = dtend)
      schedule_object.occurs_between?(from, to, spans: true) # consider also overlap of [from, to] with [starttime, starttime + duration]
    end

    def generate_uuid(data_hash)
      uuid = Digest::MD5.hexdigest(data_hash.to_s)
      [uuid[0..7], '-', uuid[8..11], '-', uuid[12..15], '-', uuid[16..19], '-', uuid[20..32]].join
    end

    module ClassMethods
      def until_as_utc(until_date, until_time)
        return if until_date.blank? || until_time.blank?

        parsed_until_date = until_date
        parsed_until_date = parsed_until_date[:time]&.in_time_zone(parsed_until_date[:zone]) if parsed_until_date.is_a?(::Hash) && parsed_until_date.key?(:time)
        parsed_until_time = until_time
        parsed_until_time = parsed_until_time.in_time_zone if parsed_until_time.is_a?(::String)

        "#{parsed_until_date.to_date.iso8601}T#{parsed_until_time.strftime('%T')}+00:00".to_datetime.utc
      end

      def to_h_from_schedule_params(value)
        return nil if value.blank? || value.values.blank?

        value.values.map { |s|
          s = s['datahash'] if s.key?('datahash')
          next nil if s.dig('start_time', 'time').blank?

          start_time = s.dig('start_time', 'time')&.in_time_zone
          start_time = start_time.beginning_of_day if s.dig('start_time', 'time')&.size == 10 # check if end_time is Date or DateTime by string size comparison xxxx-xx-xx == size 10

          if (end_time = s.dig('end_time', 'time').presence&.in_time_zone).present?
            s['duration'] = iso8601_duration(start_time, s.dig('end_time', 'time').size == 10 ? end_time.end_of_day : end_time).iso8601 # check if end_time is Date or DateTime by string size comparison xxxx-xx-xx == size 10
          else
            s['duration'] = parts_to_iso8601_duration(s['duration']).iso8601
          end

          s['start_time'] = {
            time: start_time.to_s,
            zone: start_time.time_zone.name
          }

          s['rrules'][0]['until'] = until_as_utc(s.dig('rrules', 0, 'until'), start_time) if s.dig('rrules', 0, 'until').present?
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
          when 'IceCube::MonthlyRule'
            s.dig('rrules', 0, 'validations', 'day')&.map!(&:to_i)

            if s.dig('rrules', 0, 'validations', 'day_of_week').present?
              begin
                s['rrules'][0]['validations']['day_of_week'] = JSON.parse(s.dig('rrules', 0, 'validations', 'day_of_week'))
              rescue JSON::ParserError
                s.dig('rrules', 0, 'validations')&.delete('day_of_week')
              end
            end

            if s.dig('rrules', 0, 'validations', 'day_of_month').present?
              begin
                s['rrules'][0]['validations']['day_of_month'] = JSON.parse(s.dig('rrules', 0, 'validations', 'day_of_month'))
              rescue JSON::ParserError
                s.dig('rrules', 0, 'validations')&.delete('day_of_month')
              end
            end
          when 'IceCube::YearlyRule'
            from_yday = start_time&.to_date&.yday

            s['rrules'][0]['validations']['day_of_year'] = [from_yday]
            s.dig('rrules', 0, 'validations')&.delete('day')
          else
            s.dig('rrules', 0, 'validations')&.delete('day_of_week')
            s.dig('rrules', 0, 'validations')&.delete('day_of_month')
            s.dig('rrules', 0, 'validations')&.delete('day')
          end

          transform_data_for_data_hash(s.deep_reject { |_, v| DataCycleCore::DataHashService.blank?(v) }).merge(id: s['id'])
        }.compact
      end

      def to_h_from_opening_time_params(value)
        return if value.blank? || value.values.blank?

        value.values.map { |s|
          s = s['datahash'] if s.key?('datahash')

          next if s&.dig('time').presence&.values.blank?
          next unless s.dig('rrules', 0, 'validations', 'day').present? || s['holiday'] == 'true'
          next if s['valid_from'].blank?

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

            transform_data_for_data_hash({
              id: t['id'],
              start_time: {
                time: start_time.to_s,
                zone: start_time.time_zone.name
              },
              holidays: s['holiday'] == 'ignore' ? nil : s['holiday'] == 'true',
              duration:,
              rtimes: s['holiday'] == 'true' ? holidays : nil,
              extimes: s['holiday'] == 'false' ? holidays : nil,
              rrules: [{
                rule_type: 'IceCube::WeeklyRule',
                validations: {
                  day: days
                },
                until: until_as_utc(s['valid_until'], start_time)
              }]
            }.deep_reject { |_, v| DataCycleCore::DataHashService.blank?(v) }).merge(id: t['id'])
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
        if end_time > '24:00:00'
          et = end_time.split(':')
          et[0] = (et[0].to_i - 24).to_s
          end_time = et.join(':')
        end
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

      def to_h_from_schema_org(data)
        return if data.blank?

        time_zone = data['scheduleTimezone'] || Time.zone_default.name

        start_time = {
          time: data.values_at('startDate', 'startTime').compact_blank.join('T')&.in_time_zone(time_zone),
          zone: time_zone
        }

        return if start_time[:time].blank?

        if data.key?('startTime') && data.key?('endTime') && !data.key?('duration')
          data['duration'] = iso8601_duration(
            data.values_at('startDate', 'startTime').compact_blank.join('T')&.in_time_zone(time_zone),
            data.values_at('startDate', 'endTime').compact_blank.join('T')&.in_time_zone(time_zone)
          )
        end

        rrule = {}
        rrule[:rule_type] = REPEAT_FREQUENCY_MAPPING[data['repeatFrequency'].to_s[-1]]
        if rrule[:rule_type].present?
          rrule[:until] = data.values_at('endDate', 'endTime').compact_blank.join('T')&.in_time_zone(time_zone)
          rrule[:interval] = data['repeatFrequency'].to_s[1..-2].to_i
          rrule[:validations] = {}
          rrule[:validations][:hour_of_day] = [start_time[:time].to_datetime.hour]
          rrule[:validations][:minute_of_hour] = [start_time[:time].to_datetime.minute]

          if data.key?('byMonthDay') && rrule[:rule_type] == 'IceCube::MonthlyRule'
            rrule[:validations][:day_of_month] = Array.wrap(data['byMonthDay'])
          elsif data.key?('byMonthWeek') && data.key?('byDay') && rrule[:rule_type] == 'IceCube::MonthlyRule'
            rrule[:validations][:day_of_week] = DAY_OF_WEEK_MAPPING.select { |_k, v| v.in?(Array.wrap(data['byDay'])) }.keys.index_with { |_k| Array.wrap(data['byMonthWeek']) }
          elsif data.key?('byDay')
            rrule[:validations][:day] = DAY_OF_WEEK_MAPPING.select { |_k, v| v.in?(Array.wrap(data['byDay'])) }.keys
          end
        end

        schedule_hash = {
          start_time:,
          duration: data['duration'],
          rrules: Array.wrap(rrule.deep_reject { |_, v| v.blank? }).compact_blank.presence
        }

        transform_data_for_data_hash(schedule_hash)
      end

      def duration_to_iso8601_string(data)
        if data.is_a?(ActiveSupport::Duration) && !data.zero?
          data.iso8601
        elsif data.is_a?(::Hash)
          duration = parts_to_iso8601_duration(data)
          duration.zero? ? nil : duration.iso8601
        elsif data.is_a?(Numeric) && data.positive?
          ActiveSupport::Duration.build(data).iso8601
        elsif data.is_a?(String) && data != 'PT0S'
          duration = ActiveSupport::Duration.parse(data)
          duration.zero? ? nil : duration.iso8601
        end
      rescue ActiveSupport::Duration::ISO8601Parser::ParsingError
        nil
      end

      def add_missing_rrule_values!(rrule, data)
        if rrule.key?(:interval)
          rrule[:interval] = rrule[:interval].to_i
        else
          rrule[:interval] = 1
        end

        rrule[:until] = until_as_utc(rrule[:until], data.dig(:start_time, :time)) if rrule[:until].present?

        add_missing_rrule_validations!(rrule, data)

        rrule
      end

      def add_missing_rrule_validations!(rrule, data)
        rrule[:validations] = {} unless rrule.key?(:validations)
        start_time = data.dig(:start_time, :time)

        rrule[:validations][:hour_of_day] = rrule[:validations][:hour_of_day].presence&.map(&:to_i)&.sort || [start_time.hour]
        rrule[:validations][:minute_of_hour] = rrule[:validations][:minute_of_hour].presence&.map(&:to_i)&.sort || [start_time.min]

        if rrule[:rule_type] == 'IceCube::WeeklyRule'
          rrule[:week_start] = rrule[:week_start].to_i
          rrule[:validations][:day] = rrule[:validations][:day].map(&:to_i).sort if rrule[:validations].key?(:day)
        else
          rrule.delete(:week_start)
        end

        if rrule[:rule_type] == 'IceCube::MonthlyRule'
          if rrule[:validations][:day_of_week].is_a?(::String)
            begin
              rrule[:validations][:day_of_week] = JSON.parse(rrule[:validations][:day_of_week])
            rescue JSON::ParserError
              rrule[:validations].delete(:day_of_week)
            end
          elsif rrule[:validations][:day_of_week].is_a?(::Hash)
            rrule[:validations][:day_of_week] = rrule[:validations][:day_of_week].to_h { |k, v| [k.to_i, v.map(&:to_i).sort] }
          end

          if rrule[:validations][:day_of_month].is_a?(::String)
            begin
              rrule[:validations][:day_of_month] = JSON.parse(rrule[:validations][:day_of_month])
            rescue JSON::ParserError
              rrule[:validations].delete(:day_of_month)
            end
          else
            rrule[:validations][:day_of_month]&.map!(&:to_i)&.sort!
          end
        else
          rrule[:validations]&.delete(:day_of_month)
        end

        if rrule[:rule_type] == 'IceCube::YearlyRule'
          rrule[:validations][:day_of_year] = rrule[:validations][:day_of_year].presence&.map(&:to_i)&.sort || [start_time.yday]
        else
          rrule[:validations]&.delete(:day_of_year)
        end

        rrule[:validations].delete(:minute_of_hour) if rrule[:validations][:minute_of_hour].presence&.all?(&:zero?)
        rrule
      end

      def transform_data_for_data_hash(schedule_hash)
        data = schedule_hash.with_indifferent_access.except(:relation, :thing_id)

        data[:end_time] = {} unless data.key?(:end_time)
        data[:start_time][:time] = data.dig(:start_time, :time).in_time_zone(data.dig(:start_time, :zone) || Time.zone.name) if data.dig(:start_time, :time).is_a?(::String)
        data[:end_time][:time] = data.dig(:end_time, :time).in_time_zone(data.dig(:end_time, :zone) || Time.zone.name) if data.dig(:end_time, :time).is_a?(::String)

        data[:duration] = iso8601_duration(data[:start_time][:time], data[:end_time][:time]) if data.key?(:end_time) && !data.key?(:duration)
        data[:duration] = duration_to_iso8601_string(data[:duration]) if data.key?(:duration)
        data[:end_time][:time] = data.dig(:start_time, :time).advance(iso8601_duration_to_parts(data[:duration]).to_h) if data.dig(:end_time, :time).blank? && data.key?(:duration) && data.key?(:start_time)

        data[:start_time][:zone] = data.dig(:start_time, :time).time_zone.name if data.dig(:start_time, :zone).blank?
        data[:end_time][:zone] = data.dig(:end_time, :time).time_zone.name if data.dig(:end_time, :zone).blank?

        data[:rrules] = [] if data.dig(:rrules, 0, :rule_type) == 'IceCube::SingleOccurrenceRule' || data[:rrules].blank?
        data[:rtimes] = nil if data[:rtimes].blank?
        data[:extimes] = nil if data[:extimes].blank?
        data.delete(:duration) if data[:duration].blank?

        data[:rrules].each { |rrule| add_missing_rrule_values!(rrule, data) }

        data[:start_time][:time] = data[:start_time][:time].utc if data[:start_time][:time].is_a?(ActiveSupport::TimeWithZone) && data[:start_time][:time].zone != 'UTC'
        data[:end_time][:time] = data[:end_time][:time].utc if data[:end_time][:time].is_a?(ActiveSupport::TimeWithZone) && data[:end_time][:time].zone != 'UTC'

        data
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
      before_save :serialize_schedule_object

      def history?
        true
      end

      def to_h
        super.merge(thing_history_id:)
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
    before_save :serialize_schedule_object

    def history?
      false
    end

    def to_h
      super.merge(thing_id:)
    end
    alias to_hash to_h

    def from_h(hash)
      self.thing_id = hash[:thing_id] || thing_id
      super
    end
    alias from_hash from_h

    def self.first_by_external_key_or_id(external_key, external_system_id)
      return if external_key.blank?

      query = '(external_source_id = :external_system_id AND external_key = :external_key)'
      query += ' OR id = :external_key' if external_key.uuid?

      find_by(query, external_system_id:, external_key:)
    end
  end
end

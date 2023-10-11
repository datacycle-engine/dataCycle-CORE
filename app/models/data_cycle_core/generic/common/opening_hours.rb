# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      class OpeningHours
        DAY_HASH = { 'Monday' => 'Montag', 'Tuesday' => 'Dienstag', 'Wednesday' => 'Mittwoch', 'Thursday' => 'Donnerstag', 'Friday' => 'Freitag', 'Saturday' => 'Samstag', 'Sunday' => 'Sonntag' }.freeze
        FORMATS = [:google, :opening_hours_specification].freeze
        CLOSED_STRING = 'geschlossen'

        attr_reader :data, :validity

        def initialize(data_hash, validity: nil, format: nil, options: {})
          @validity = validity
          @options = options
          @data =
            case format
            when :google
              raise StandardError unless data_hash.is_a?(::Hash) || data_hash.nil?
              parse_google(data_hash || {})
            when :opening_hours_specification
              raise StandardError unless data_hash.is_a?(::Array) || data_hash.nil?
              parse_opening_hours_specification(data_hash || [])
            else
              raise NotImplementedError, "only formats #{FORMATS.map(&:to_s).join(', ')} are implemented"
            end
          simplify_all_ranges
        end

        def to_per_day_opening_hours
          return nil if empty?
          data
            .map { |day, ranges| { DAY_HASH[day] => ranges.map { |range| convert_range_to_string(range) }.join(', ') } }
            .map { |day_hash| day_hash.values.first.present? ? day_hash : { day_hash.keys.first => CLOSED_STRING } }
            .inject(&:merge)
        end

        def to_opening_hours_specifications
          return nil if empty?
          day_of_week_classification_ids = DAY_HASH
            .map { |key, value| { key => DataCycleCore::ClassificationAlias.for_tree('Wochentage').find_by(name: value).classifications.first.id } }
            .reduce(&:merge)
          DAY_HASH
            .keys
            .map { |day| data[day] }
            .flatten
            .map { |range| [range.first, range.last] }
            .flatten
            .uniq
            .sort
            .each_cons(2)
            .map { |from, to|
              {
                'day_of_week' => days_in_range((from...to)).map { |day| day_of_week_classification_ids[day] },
                'validity' => @validity,
                'time' => [{
                  'opens' => convert_to_time_string(from),
                  'closes' => convert_to_time_string(to)
                }]
              }
            }
            .select { |item| item.dig('day_of_week').size.positive? }
        end

        def empty?
          return true if @data.empty?
          @data.count { |_day, ranges| ranges.present? }.zero?
        end

        def self.parse_opening_times(data, external_source_id, external_key, day_transformation = nil)
          return nil if data.blank?

          transformed_data = Array.wrap(data).map { |item|
            next if item.blank? || item['TimeFrom'].blank? || item['TimeTo'].blank?
            item['external_key'] = Digest::SHA1.hexdigest "#{external_key}-#{item.to_json}"
            item
          }.compact

          existing = DataCycleCore::Schedule.where(external_source_id:, external_key: transformed_data.pluck('external_key')).index_by(&:external_key)

          transformed_data.map { |item|
            preprocess_opening_time(data, external_source_id, item['external_key'], day_transformation, existing[item['external_key']]&.id)
          }.compact
        end

        def self.parse_opening_times_reference(data, external_source_id, external_key, day_transformation = nil)
          return nil if data.blank?

          Array.wrap(data).map { |item|
            next if item.blank? || item['TimeFrom'].blank? || item['TimeTo'].blank?
            external_schedule_key = Digest::SHA1.hexdigest "#{external_key}-#{data.to_json}"
            schedule_id = DataCycleCore::Generic::Common::DataReferenceTransformations.get_external_schedule_references(item, external_source_id, ->(*) { external_schedule_key })&.first
            preprocess_opening_time(data, external_source_id, external_schedule_key, day_transformation, schedule_id)
          }.compact
        end

        def self.preprocess_opening_time(data, external_source_id, external_key, day_transformation, schedule_id)
          if data['TimeFrom'].is_a?(ActiveSupport::TimeWithZone) && data['DateFrom'].is_a?(ActiveSupport::TimeWithZone) && data['TimeFrom'] == data['DateFrom']
            start_time = data['TimeFrom']
            duration = DataCycleCore::Schedule.time_to_duration(data['TimeFrom'].strftime('%k:%M:%S'), data['TimeTo'].strftime('%k:%M:%S'))
          else
            start_time = "#{data['DateFrom']} #{data['TimeFrom']}".in_time_zone
            duration = DataCycleCore::Schedule.time_to_duration(data['TimeFrom'], data['TimeTo'])
          end
          until_time = data['DateTo']&.to_datetime&.end_of_day&.utc&.change(usec: 0) || 3.years.from_now.to_datetime.end_of_day.utc&.change(usec: 0) # !! use :to_datetime (until has to be given in UTC of local time)
          days = day_transformation.present? ? day_transformation&.call(data) : data['WeekDays']
          days = (0...7).to_a if days.blank?

          if (data['Holiday'] == true && (0...7).to_a.difference(days).present?) || data['Holiday'] == false
            holidays = Holidays
              .between(start_time, until_time, Array.wrap(DataCycleCore.holidays_country_code))
              .map { |d| { time: "#{d[:date]} #{start_time.to_s(:time)}".in_time_zone, zone: start_time.time_zone.name } }
          end

          DataCycleCore::Schedule.new.from_hash({
            external_source_id:,
            external_key:,
            start_time: {
              time: start_time.to_s,
              zone: start_time.time_zone.name
            },
            holidays: data['Holiday'],
            duration:,
            rtimes: data['Holiday'] == true ? holidays : data['rtimes']&.compact_blank.presence,
            extimes: data['Holiday'] == false ? holidays : data['extimes']&.compact_blank.presence,
            rrules: [{
              rule_type: 'IceCube::WeeklyRule',
              validations: {
                day: days
              },
              until: until_time
            }]
          }.deep_reject { |_, v| DataCycleCore::DataHashService.blank?(v) }.with_indifferent_access).to_hash.except(:relation, :thing_id).merge(id: schedule_id).with_indifferent_access.compact
        end

        private

        def parse_google(data_hash)
          DAY_HASH
            .keys
            .map { |day| data_hash&.dig(day)&.map { |interval| parse_google_interval(interval) }&.compact || [] }
            .zip(DAY_HASH.keys)
            .map { |data_interval| { data_interval[1] => data_interval[0] } }
            .inject(&:merge)
        end

        def parse_opening_hours_specification(data_hash)
          day_of_week_classification_ids = DAY_HASH
            .map { |key, value| { key => DataCycleCore::ClassificationAlias.for_tree('Wochentage').find_by(name: value).classifications.first.id } }
            .reduce(&:merge)
          DAY_HASH
            .keys
            .map { |day|
              {
                day =>
                  data_hash
                    .select { |record| record&.dig('day_of_week')&.include?(day_of_week_classification_ids[day]) }
                    .map { |record| record.dig('time').map { |time| parse_opening_hours_interval(time) } }
                    .flatten
              }
            }
            .inject(&:merge)
        end

        def simplify_all_ranges
          return if @data.blank?
          DAY_HASH.each_key do |day|
            next if @data.dig(day).size < 2
            @data[day] = simplify_ranges(@data.dig(day).sort_by(&:min))
          end
          self
        end

        def simplify_ranges(ranges)
          intervals = ranges
          finished = false
          until finished
            intervals.each_index do |i|
              if i + 1 == intervals.size
                finished = true
                next
              end
              if intervals[i].max >= intervals[i + 1].min
                intervals[i + 1] = (intervals[i].min..[intervals[i].max, intervals[i + 1].max].max)
                intervals[i] = nil
              end
            end
            intervals = intervals.compact
          end
          intervals
        end

        def days_in_range(interval)
          DAY_HASH.keys.select { |day| data[day].map { |range| range.include?(interval) }.inject(&:|) }
        end

        def parse_google_interval(data)
          return nil if data&.dig('open').blank? || data&.dig('close').blank?
          opens = data.dig('open')
          closes = data.dig('close')
          parse_time_interval(opens, closes)
        end

        def parse_opening_hours_interval(data)
          return nil if data&.dig('opens')&.blank? || data&.dig('closes').blank?
          opens = data.dig('opens')
          closes = data.dig('closes')
          parse_time_interval(opens, closes)
        end

        def parse_time_interval(string_opens, string_closes)
          opens = convert_to_i(string_opens)
          closes = convert_to_i(string_closes)
          closes = convert_to_i(string_closes, opens > closes)
          return nil if opens.negative? || closes.negative?
          return nil if opens > closes
          return nil if opens > 24 * 60 * 60
          return nil if closes > 48 * 60 * 60 # due to next day (2*24)
          (opens..closes)
        end

        def convert_to_time_string(number)
          hh = number / (60 * 60)
          mm = (number - hh * 60 * 60) / 60
          hh -= 24 if hh >= 24
          [hh.to_s, mm.to_s.rjust(2, '0')].join(':')
        end

        def convert_to_i(string, next_day = false)
          if @options.dig(:wrong_time_format).present?
            string.split(':')
              .rotate(1)
              .map(&:to_i)
              .zip(next_day ? [24, 0, 0] : [0, 0, 0])
              .map { |item| item.inject(&:+) }
              .zip([60 * 60, 60, 1])
              .map { |item| item.inject(&:*) }
              .inject(&:+)
          elsif string.split(':').size == 3
            string.split(':')
              .map(&:to_i)
              .zip(next_day ? [24, 0, 0] : [0, 0, 0])
              .map { |item| item.inject(&:+) }
              .zip([60 * 60, 60, 1])
              .map { |item| item.inject(&:*) }
              .inject(&:+)
          elsif string.split(':').size == 2
            string.split(':')
              .map(&:to_i)
              .zip(next_day ? [24, 0] : [0, 0])
              .map { |item| item.inject(&:+) }
              .zip([60 * 60, 60])
              .map { |item| item.inject(&:*) }
              .inject(&:+)
          end
        end

        def convert_range_to_string(range)
          "#{convert_to_time_string(range.first)} - #{convert_to_time_string(range.last)}"
        end
      end
    end
  end
end

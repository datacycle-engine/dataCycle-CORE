# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module TransformationSchedules
        def self.transform_schedule(data)
          return data if data.dig('Details', 'StartTimes').blank?

          duration = data.dig('Details', 'Duration', 'text')
          new_duration = data.dig('Details', 'Duration').except('text')

          dates = Array.wrap(data.dig('Details', 'Dates', 'Date'))
          times = Array.wrap(data.dig('Details', 'StartTimes', 'StartTime'))
          new_dates = { 'Date' => dates.map { |date_data| times.map { |time_data| date_data.merge({'Duration' => duration }).merge(time_data) } }.flatten }

          new_details = data.dig('Details').except('StartTimes')
          new_details['Duration'] = new_duration
          new_details['Dates'] = new_dates
          data['Details'] = new_details
          data
        end

        def self.add_legacy_event_schedule(data, external_source_id)
          available_dates = Array.wrap(data.dig('Dates', 'Date')).uniq
          res = []
          return data if available_dates.blank?

          available_dates.each do |date|
            start_date = date['From']
            end_date = date['To']
            time_res = {
              event_date: {
                start_date: start_date,
                end_date: end_date
              }
            }
            if date['Time'].present?
              start_time = date['Time'].to_datetime
              duration = event_duration(data.dig('Duration', 'Type'), date['Duration'])
              time_res[:day_of_week] = date
                .except('From', 'To', 'Duration', 'Time')
                .select { |_day, val| val == 'true' }
                .map { |key, _val| load_day_of_week_id(key) }
                &.reject(&:blank?)
              end_time = duration ? (start_time + duration.minutes).strftime('%H:%M') : nil
              time_res[:event_time] = {
                start_time: start_time&.strftime('%H:%M'),
                end_time: end_time
              }
            end
            res << time_res
          end
          data['schedule'] = res
            .flatten
            .sort_by { |o| o[:event_date][:start_date] }
            .map do |item|
              schedule_key = Digest::SHA1.hexdigest "#{data.dig('external_key')}-#{item.to_json}"
              item.merge({
                id: DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: schedule_key)&.id,
                external_source_id: external_source_id,
                external_key: schedule_key
              })
            end
          data
        end

        def self.add_schedules(data, external_source_id)
          return data if data.dig('Dates', 'Date').blank?

          available_dates = Array.wrap(data.dig('Dates', 'Date')).uniq
          res = []
          options = {}

          available_dates.each do |date|
            dstart = date['From'].presence
            dend = date['To'].presence
            duration = duration(data.dig('Duration', 'Type'), date['Duration']) || 0
            options = { duration: duration } if duration.positive?
            options = {} if duration > 1.day && dend.present? # duration is interpreted for the entierty of all event not only a single event

            if date['Time'].present?
              tstart = date['Time']
              dtstart = "#{dstart}T#{tstart}".in_time_zone
              dtend = nil
              if dend.present?
                dtend = "#{dend}T#{tstart}".in_time_zone
                untild = dtend
                if duration == 1.day && dstart == dend
                  dtend = dtend.end_of_day
                elsif duration < 1.day
                  dtend += duration
                end
              elsif duration.present?
                dtend = dtstart + duration
                untild = dtstart
              else
                dtend = dtstart
                untild = dtstart
              end
              untildt = DataCycleCore::Schedule.until_as_utc_iso8601(untild, dtstart).to_datetime.utc

              active_days = date
                .except('From', 'To', 'Duration', 'Time')
                .select { |_day, val| val == 'true' }
                .map { |day, _val| load_day_nr(day) }
                .compact
                .presence

              rrule = active_days&.size.to_i.in?(1..6) ? IceCube::Rule.weekly : IceCube::Rule.daily

              time = tstart.to_datetime
              rrule.hour_of_day(time.hour)
              rrule.minute_of_hour(time.minute) if time.minute.positive?
              rrule.day(active_days) if active_days.present?
              rrule.until(untildt)
              schedule_object = IceCube::Schedule.new(dtstart, options) do |s|
                s.add_recurrence_rule(rrule)
              end
              res << schedule_object.to_hash.merge(dtstart: dtstart, dtend: dtend).compact if schedule_object.all_occurrences.size.positive?
            else
              dstart = nil
              dend = nil
              dstart = Time.zone.parse(date['From']) if date['From'].present?
              dend = Time.zone.parse(date['To'])&.end_of_day if date['To'].present?

              res << {
                start_time: { time: dstart, zone: dstart.time_zone.name },
                end_time: { time: dend, zone: dend.time_zone.name },
                duration: dend.to_i - dstart.to_i
              }
            end
          end
          data['event_schedule'] = res
            .sort_by { |item| item[:dtstart] }
            .map do |item|
              schedule_key = Digest::SHA1.hexdigest "#{data.dig('external_key')}-#{item.to_json}"
              item.merge({
                id: DataCycleCore::Schedule.find_by(external_source_id: external_source_id, external_key: schedule_key)&.id,
                thing_id: DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: data['external_key'])&.id,
                relation: 'event_schedule',
                external_source_id: external_source_id,
                external_key: schedule_key
              }.compact_blank)
            end
          data
        end

        def self.duration(type, value)
          return nil if value.is_a?(::Array)
          case type
          when nil, 'None'
            nil
          when 'Day'
            value.to_f * 24 * 60 * 60
          when 'Hour'
            value.to_f * 60 * 60
          when 'Minute'
            value.to_f * 60
          else
            raise "Unknown duration type '#{type}'"
          end
        end

        def self.event_duration(type, value)
          case type
          when nil, 'None', 'Day'
            nil
          when 'Hour'
            value.to_f * 60
          when 'Minute'
            value.to_f
          else
            raise "Unknown duration type '#{type}'"
          end
        end

        def self.load_day_nr(day)
          return nil unless ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].include?(day)
          { 'Mon' => 1, 'Tue' => 2, 'Wed' => 3, 'Thu' => 4, 'Fri' => 5, 'Sat' => 6, 'Sun' => 0 }[day]
        end

        def self.load_day_of_week_id(day)
          return nil unless ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].include?(day)
          day_hash = {
            'Mon' => 'Montag',
            'Tue' => 'Dienstag',
            'Wed' => 'Mittwoch',
            'Thu' => 'Donnerstag',
            'Fri' => 'Freitag',
            'Sat' => 'Samstag',
            'Sun' => 'Sonntag'
          }
          DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Wochentage', day_hash[day])
        end
      end
    end
  end
end

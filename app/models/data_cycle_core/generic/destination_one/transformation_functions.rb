# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DestinationOne
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.add_info(data, external_source_id)
          return data if data['texts'].blank?
          html_texts = data['texts']
            .select { |text| text['type'] == 'text/html' && text['value']&.strip.present? && text['rel']&.strip.present? }
            .map { |text| text['rel'] }
          additional_information = data['texts']
            .select { |text| text['value']&.strip.present? && text['rel']&.strip.present? }
            .select { |text| text['type'].in?(['text/html', 'text/plain']) }
            .reject { |text| (text['rel'].in?(html_texts) && text['type'] != 'text/html') }
            .map { |text|
              type = text['rel'].downcase
              external_key = "destination.one - AdditionalInformation - #{data.dig('external_key')} - #{text['rel']}"
              {
                'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id,
                'external_key' => external_key,
                'name' => I18n.t("import.destination_one.#{type}", default: [type]),
                'universal_classifications' => Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', type)),
                'description' => text['value']
              }.compact
            }.compact
          data['additional_information'] = additional_information
          data
        end

        def self.add_ccc(data, license)
          key = license.call(data)
          return data if key.blank? || !key.starts_with?('CC')
          key = key.split('-')
          data['license_classification'] = DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Lizenzen', "#{key[0]} #{key[1..-1].join('-')}")
          data
        end

        def self.add_tour(data, geometry)
          geo_data = geometry.call(data)
          return data if geo_data.blank?
          factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          data['line'] = factory.multi_line_string(
            Array.wrap(
              factory.line_string(
                geo_data
                  .split
                  .each_slice(2)
                  .map { |long, lat| factory.point(lat.to_f, long.to_f) }
              )
            )
          )
          data
        end

        def self.add_opening_hours_specification(data, external_source_id)
          parse_opening_hours_specification(data, external_source_id, 'opening_hours_specification', 'timeIntervals')
        end

        def self.add_dining_hours_specification(data, external_source_id)
          parse_opening_hours_specification(data, external_source_id, 'dining_hours_specification', 'kitchenTimeIntervals')
        end

        def self.parse_opening_hours_specification(data, external_source_id, property, attribute)
          return data if data.dig(attribute).blank?
          data[property] = []
          data.dig(attribute).uniq.each do |time|
            dtstart = time['start']&.in_time_zone
            dtend = time['end']&.in_time_zone
            dtuntil = time['repeatUntil']&.in_time_zone || Time.zone.now.end_of_year + 5.years
            if time['freq'].blank? && time['start'].present? # single entry
              dtuntil = dtend
              wdays = Array.wrap(dtstart.wday)
            else
              wdays = days(time['weekdays'])
            end
            data[property] << DataCycleCore::Generic::Common::OpeningHours.parse_opening_times({
              'TimeFrom' => dtstart,
              'DateFrom' => dtstart,
              'TimeTo' => dtend,
              'DateTo' => dtuntil.to_date,
              'WeekDays' => wdays
            }, external_source_id, "#{data['external_key']} - #{property} - #{time.to_json}")
          end
          data[property] = data[property]&.flatten
          data
        end

        def self.add_event_schedule(data, external_source_id)
          return data if data.dig('timeIntervals').blank?
          schedule = []
          data.dig('timeIntervals').uniq.each do |time|
            next if time['start'].blank? || time['end'].blank?

            external_key = Digest::SHA1.hexdigest("#{data['external_key']} - event_schedule - #{time.to_json}")
            id = DataCycleCore::Schedule.find_by(external_source_id: external_source_id, external_key: external_key)&.id

            dtstart = time['start'].in_time_zone
            dtend = time['end'].in_time_zone
            duration = dtend - dtstart
            until_time = time['repeatUntil']&.in_time_zone || Time.zone.now.end_of_year + 5.years

            schedule_hash = {
              id: id,
              external_source_id: external_source_id,
              external_key: external_key,
              start_time: {
                time: dtstart.to_s,
                zone: time['tz']
              },
              duration: duration
            }

            case time['freq']
            when nil, 'Single'
              schedule << schedule_hash
            when 'Daily'
              rrule = IceCube::Rule.daily
              rrule.hour_of_day(dtstart.hour)
              rrule.minute_of_hour(dtstart.to_datetime.minute)
              rrule.interval(time['interval']) if time['interval'].present?
              rrule.until(until_time)
              schedule << schedule_hash.merge({ rrules: [rrule.to_hash] })
            when 'Weekly'
              rrule = IceCube::Rule.weekly
              rrule.day(*days(time['weekdays'])) if time['weekdays'].present?
              rrule.interval(time['interval']) if time['interval'].present?
              rrule.until(until_time)
              schedule << schedule_hash.merge({ rrules: [rrule.to_hash] })
            when 'Monthly'
              rrule = IceCube::Rule.monthly
              rrule.day_of_month(time['dayOfMonth']) if time['dayOfMonth'].present?
              rrule.day_of_week(time['weekday'].downcase.to_sym => [time['dayOrdinal']]) if time['weekday'].present? && time['dayOrdinal'].present? # e.g. 4th sunday each month
              rrule.interval(time['interval']) if time['interval'].present?
              rrule.until(until_time)
              schedule << schedule_hash.merge({ rrules: [rrule.to_hash] })
            when 'Yearly'
              rrule = IceCube::Rule.yearly
              rrule.month_of_year(time['month'])
              rrule.day_of_month(time['dayOfMonth'])
              rrule.interval(time['interval']) if time['interval'].present?
              rrule.until(until_time)
              schedule << schedule_hash.merge({ rrules: [rrule.to_hash] })
            end
          end
          data['event_schedule'] = schedule
          data
        end

        def self.days(weekdays)
          return [] if weekdays.blank?
          wd = []
          weekdays.each do |i|
            wd << {
              'Monday' => 1,
              'Tuesday' => 2,
              'Thursday' => 3,
              'Wednesday' => 4,
              'Friday' => 5,
              'Saturday' => 6,
              'Sunday' => 0
            }[i]
          end
          wd
        end
      end
    end
  end
end

# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Timm4
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.add_info(data, fields, external_source_id)
          additional_information = fields.map { |type|
            next if data[type].blank?
            external_key = "TIMM4 - AdditionalInformation - #{data.dig('id')} - #{type}"
            {
              'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id,
              'external_key' => external_key,
              'name' => I18n.t("import.timm4.#{type}", default: [type]),
              'universal_classifications' => Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', type)),
              'description' => data[type]
            }.compact
          }.compact
          data['additional_information'] = additional_information
          data
        end

        def self.add_contact_name(data, address_attribute = nil)
          address = address_attribute.present? ? data['address_attribute'] : data
          return data if address.blank?
          org = nil
          org = address['organization'] if address['organization']
          contact_name = [address['formOfAddress'], address['firstname'], address['lastname']].compact.join(' ').presence
          data['contact_name'] = [org, contact_name].compact.join(' - ')
          data
        end

        def self.add_location_name(data)
          return data if data['name'].present?
          name = [data['formOfAddress'], data['firstname'], data['lastname']].compact.join(' ').presence
          data['name'] = name.presence || '__no_name__'
          data
        end

        def self.add_url(data)
          return data if data.dig('links').blank?
          url = data.dig('links')&.first&.dig('url')
          data['url'] = url.starts_with?('http') ? url.strip : nil
          data
        end

        def self.add_images(data, external_source_id)
          images = [data.dig('img'), data.dig('image'), data.dig('images'), data.dig('mainImage')]
            .flatten
            .compact
            .map { |i| DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: i)&.id }
            .compact
          data['image'] = images
          data
        end

        def self.add_opening_hours_specification(data, external_source_id)
          parse_opening_hours_specification(data, external_source_id, 'opening_hours_specification', 'openingTimes')
        end

        def self.add_dining_hours_specification(data, external_source_id)
          parse_opening_hours_specification(data, external_source_id, 'opening_hours_specification', 'kitchenTimes')
        end

        def self.parse_opening_hours_specification(data, external_source_id, property, attribute)
          return data if data.dig(attribute, 'times').blank?
          data[property] = []
          data.dig(attribute, 'times').each_with_index do |time, index|
            holidays = true if time['weekdays'].include?(8)
            opening_hours_days = time['weekdays'].select { |i| i < 8 }.map { |i| i == 7 ? 0 : i }
            if time['startDate'].present? && time['endDate'].present?
              start_day = time['startDate'].split('-')[2]&.to_i
              start_month = time['startDate'].split('-')[1]&.to_i
              start_day += 1 if start_day.zero?
              date_from = Time.new(Time.zone.now.year, start_month, start_day).in_time_zone

              end_day = time['endDate'].split('-')[2]&.to_i
              end_month = time['endDate'].split('-')[1]&.to_i
              end_day += 1 if end_day.zero?
              date_to = Time.new(Time.zone.now.year, end_month, end_day).in_time_zone

              next_year = date_from > date_to ? 1 : 0
              (0..5).each do |future|
                processed = DataCycleCore::Generic::Common::OpeningHours.parse_opening_times({
                  'TimeFrom' => time['startTime'],
                  'DateFrom' => (date_from + future.years).to_date,
                  'TimeTo' => time['endTime'],
                  'DateTo' => (date_to + (future + next_year).years).to_date,
                  'Holiday' => holidays,
                  'WeekDays' => opening_hours_days.presence || (0..6).to_a
                }, external_source_id, "#{data['id']} - #{index} - #{future}")
                data[property].push(processed)
              end
            else
              processed = DataCycleCore::Generic::Common::OpeningHours.parse_opening_times({
                'TimeFrom' => time['startTime'],
                'DateFrom' => Time.zone.now.beginning_of_year.to_date,
                'TimeTo' => time['endTime'],
                'DateTo' => (Time.zone.now.end_of_year + 5.years).to_date,
                'Holiday' => holidays,
                'WeekDays' => opening_hours_days
              }, external_source_id, "#{data['id']} - #{index}")
              data[property].push(processed)
            end
          end
          data[property] = data[property]&.flatten
          data
        end

        def self.add_opening_hours_description(data)
          parse_opening_hours_description(data, 'opening_hours_description', 'openingTimes')
        end

        def self.add_dining_hours_description(data)
          parse_opening_hours_description(data, 'dining_hours_description', 'kitchenTimes')
        end

        def self.parse_opening_hours_description(data, property, attribute)
          return data if data.dig(attribute, 'additionalInformation').blank?
          data[property] = [{ 'description' => data.dig(attribute, 'additionalInformation') }]
          data
        end

        def self.add_line(data)
          return data if data['sections'].blank? || data['sections'].size.zero?
          geometry = data['sections']
          factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          lines = geometry
            .map { |section| section['line'] }
            .map { |line|
              line
                .split
                .each_slice(2)
                .map { |long, lat| factory.point(lat.to_f, long.to_f) }
            }
            .map { |line| factory.line_string(line) }
          data['line'] = factory.multi_line_string(lines)
          data
        end

        def self.add_schedule(data, external_source_id, external_key)
          return data if data['dates'].blank?
          data['event_schedule'] = []
          data['dates'].each do |date|
            next if date['date'].blank?
            next if date['date'].present? && date['dateEnd'].present? && date['date'].in_time_zone > date['dateEnd'].in_time_zone
            dstart = date['date'].in_time_zone
            dend = date['dateEnd']&.in_time_zone || dstart
            dend = dstart if dend > (Time.zone.now + 5.years)

            if data['times'].blank?
              dtstart = dstart
              dtend = dend.end_of_day
              # data['event_schedule'] << {
              #   start_time: { time: dtstart, zone: dtstart.time_zone.name },
              #   end_time: { time: dtend, zone: dtend.time_zone.name },
              #   duration: dtend.to_i - dtstart.to_i
              # }
              data['event_schedule'] << {
                start_time: { time: dtstart, zone: dtstart.time_zone.name },
                duration: 1.day.to_i,
                rrules: [{
                  rule_type: 'IceCube::DailyRule',
                  until: dtend
                }]
              }
            else
              wdays = days(dstart, dend)
              data['times'].each do |time|
                weekday = time['weekdays'].first
                weekday -= 7 if weekday.present? && weekday > 6
                next unless (weekday.present? && wdays.include?(weekday)) || weekday.blank?

                dtstart = "#{dstart.to_s(:only_date)}T#{time['startTime']}".in_time_zone
                dtend =
                  if time['endTime'] == '00:00:00'
                    dend.end_of_day
                  elsif time['endTime'].present?
                    "#{dend.to_s(:only_date)}T#{time['endTime']}".in_time_zone
                  else # endTime is NULL
                    dtstart
                  end
                data['event_schedule'] << {
                  start_time: { time: dtstart, zone: dtstart.time_zone.name },
                  end_time: { time: dtend, zone: dtend.time_zone.name },
                  duration: dtend.to_i - dtstart.to_i
                }
              end
            end
          end
          data['event_schedule'].map! do |item|
            schedule_key = Digest::SHA1.hexdigest "#{external_key.call(data)}-#{item.to_json}"
            item.merge({
              id: DataCycleCore::Schedule.find_by(external_source_id: external_source_id, external_key: schedule_key)&.id,
              external_source_id: external_source_id,
              external_key: schedule_key
            })
          end
          data
        end

        def self.days(dstart, dend)
          return Array.wrap(dstart.wday) if dstart == dend
          days = (dend - dstart) / 1.day.to_i
          return (0..6).to_a if days >= 6
          (0..days).map { |i| (dstart + i.days).wday }.sort.uniq
        end

        def self.add_potential_action(data, external_source_id)
          potential_action = []

          ['menuDownload', 'recipeSuggestionDownload'].each do |item|
            link = data[item]&.strip
            next if link.blank?
            potential_action << {
              'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: link)&.id,
              'name' => I18n.t("import.timm4.#{item}", default: [item]),
              'url' => link,
              'action_type' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('ActionTypes', 'Download'),
              'external_key' => link
            }
          end

          data['potential_action'] = potential_action
          data
        end
      end
    end
  end
end

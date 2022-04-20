# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Toubiz
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.add_contact_info(data)
          contact_info = {}
          contact_info['url'] = validate_url(data.dig('contactInformation', 'website'))

          numbers = data.dig('phoneNumbers').select { |i| i['type'].in?(['mobile', 'phone']) }
          numbers = numbers.select { |i| i['primary'] == true } if numbers.size > 1
          contact_info['telephone'] = numbers&.first&.dig('iso5008')

          numbers = data.dig('phoneNumbers').select { |i| i['type'].in?(['fax']) }
          numbers = numbers.select { |i| i['primary'] == true } if numbers.size > 1
          contact_info['fax_number'] = numbers&.first&.dig('iso5008')

          email = data.dig('emails').detect { |i| i['primary'] == true }.presence || data.dig('emails')&.first
          contact_info['email'] = email&.dig('email')

          name = [data.dig('contactInformation', 'contactPersonFirstName'), data.dig('contactInformation', 'contactPersonLastName')].join(' ').strip.presence
          contact_info['contact_name'] = name

          data['contact_info'] = contact_info
          data
        end

        def self.add_info(data, external_source_id, field_names)
          additional_information = field_names
            .select { |type| data[type]&.strip.present? }
            .map { |type| { 'name' => type, 'description' => data[type] } }
            .map { |text|
              type = text['name']
              external_key = "mein.toubiz - AdditionalInformation - #{data.dig('external_key')} - #{type}"
              {
                'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id,
                'external_key' => external_key,
                'name' => I18n.t("import.toubiz.#{type}", default: [type]),
                'universal_classifications' => Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', type)),
                'description' => text['description']
              }
            }.compact
          data['additional_information'] = additional_information
          data
        end

        def self.add_ccc(data)
          return data if data.dig('license').blank? || !data.dig('license').starts_with?('cc')
          key = data.dig('license').upcase.split('-')
          data['license_classification'] = DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Lizenzen', "#{key[0]} #{key[1..-1].join('-')}")
          data
        end

        def self.add_tour(data)
          points = data.dig('tour', 'points')
          return data if points.blank?
          factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          data['line'] = factory.multi_line_string(
            [factory.line_string(points.map { |point| factory.point(point[1], point[0], point[2]) })]
          )
          data
        end

        def self.add_things(data, external_source_id)
          data['content_location'] = Common::Functions.find_thing_ids(external_system_id: external_source_id, external_key: data.dig('location', 'id'))
          data['linked_thing'] =
            if data.dig('host', 'id').present? && data.dig('host', 'id') != data.dig('location', 'id')
              Common::Functions.find_thing_ids(external_system_id: external_source_id, external_key: data.dig('host', 'id'))
            else
              []
            end
          data
        end

        def self.add_potential_action(data, external_source_id)
          url = validate_url(data.dig('booking', 'url').presence || data.dig('bookingUrl').presence)
          return data if url.blank?
          external_key = "#{data.dig('external_key')} - #{url}"
          data['dc_potential_action'] = [{
            'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id,
            'external_key' => external_key,
            'external_source_id' => external_source_id,
            'name' => 'booking',
            'url' => url,
            'action_type' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('ActionTypes', 'Bestellen')
          }]
          data
        end

        def self.add_urls(data)
          data['url'] = validate_url(data.dig('url'))
          data['thumbnail_url'] = data['url']
          data['content_url'] = data['url']
          data
        end

        def self.add_event_schedule(data, external_source_id)
          return data unless data.dig('hasSchedule')
          return data if data.dig('dateIntervals').blank?
          schedule = []
          data.dig('dateIntervals').uniq.each do |time|
            external_key = Digest::SHA1.hexdigest("#{data['external_key']} - event_schedule - #{time.to_json}")
            id = DataCycleCore::Schedule.find_by(external_source_id: external_source_id, external_key: external_key)&.id

            dstart = time['date']&.to_datetime || Time.current.beginning_of_year - 1.year
            tstart = time['startAt'] || '00:00:00'
            dtstart = "#{dstart.to_s(:only_date)}T#{tstart}".in_time_zone
            tend = time['endAt'] || '23:59:59'
            dtend = "#{dstart.to_s(:only_date)}T#{tend}".in_time_zone
            duration = dtend - dtstart
            duration += 1.day if duration.negative?
            until_time = time['end']&.to_datetime || Time.zone.now.end_of_year + 5.years
            until_time = "#{until_time.to_s(:only_date)}T#{tstart}".in_time_zone
            until_time = dtstart if time['end'] == time['date']

            extimes = data.dig('dates')
              .select { |i| i['isCancelled'] == true }
              .map { |i| "#{i['date']}T#{i['startAt'] || '00:00:00'}".in_time_zone }

            schedule_hash = {
              id: id,
              external_source_id: external_source_id,
              external_key: external_key,
              start_time: {
                time: dtstart.to_s,
                zone: dtstart.time_zone.name
              },
              duration: duration,
              extimes: extimes || []
            }

            case time['repeatRuleName']
            when 'none'
              schedule << schedule_hash
            when 'weekly'
              rrule = IceCube::Rule.weekly
              days = rrule_days(time.dig('configuration', 'days'))
              rrule.day(days) if days.present?
              rrule.interval(time['interval']) if time['interval'].present?
              rrule.until(until_time)
              schedule << schedule_hash.merge({ rrules: [rrule.to_hash] })
            end
          end
          data['event_schedule'] = schedule
          data
        end

        def self.rrule_days(array)
          array.map { |i| i > 6 ? i - 7 : i }
        end

        def self.validate_url(url)
          schemes = ['http', 'https', 'mailto', 'ftp', 'sftp', 'tel']
          begin
            url if schemes.include?(Addressable::URI.parse(url)&.scheme)
          rescue Addressable::URI::InvalidURIError
            nil
          end
        end
      end
    end
  end
end

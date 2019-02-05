# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Feratel::TransformationFunctions[*args]
        end

        def self.feratel_to_accommodation(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:add_links,
                'feratel_locations',
                DataCycleCore::Classification,
                external_source_id, lambda { |s|
                  s&.dig('Details', 'Town')&.yield_self { |town| town.is_a?(String) ? town : town['text'] }
                })
          .>> t(:unwrap, 'Details')
          .>> t(:rename_keys, 'Id' => 'external_key', 'Names' => 'name')
          .>> t(:unwrap, 'Position')
          .>> t(:rename_keys, 'Latitude' => 'latitude', 'Longitude' => 'longitude')
          .>> t(:map_value, 'latitude', ->(v) { v.to_f })
          .>> t(:map_value, 'longitude', ->(v) { v.to_f })
          .>> t(:location)
          .>> t(:unwrap_description, 'ServiceProviderDescription')
          .>> t(:rename_keys, 'ServiceProviderDescription' => 'description')
          .>> t(:reject_keys, ['Town'])
          .>> t(:unwrap_address, 'Object')
          .>> t(:unwrap, 'Address')
          .>> t(
            :rename_keys,
            {
              'AddressLine1' => 'street_address',
              'Town' => 'address_locality',
              'ZipCode' => 'postal_code',
              'Country' => 'address_country',
              'Fax' => 'fax_number',
              'Phone' => 'telephone',
              'Email' => 'email',
              'URL' => 'url'
            }
          )
          .>> t(:add_field, 'feratel_documents', ->(s) { s.dig('Documents', 'Document').is_a?(Hash) ? [s.dig('Documents', 'Document')] : s.dig('Documents', 'Document') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id,
                document_filter(document_classes: ['Image'], document_types: ['ServiceProvider']))
          .>> t(:add_links, 'logo', DataCycleCore::Thing, external_source_id,
                document_filter(document_classes: ['Image'], document_types: ['ServiceProviderLogo']))
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('HolidayThemes', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'accommodation_categories', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Categories', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_classifications', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Classifications', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'stars', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Stars')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('DataOwner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('DataOwner')).hexdigest}"] : [] })
          .>> t(:map_value, 'url', ->(s) { s.nil? ? '' : (!s.starts_with?('http://') && !s.starts_with?('https://') ? "http://#{s}" : s) })
          .>> t(:nest, 'address', ['street_address', 'address_country', 'address_locality', 'postal_code'])
          .>> t(:nest, 'contact_info', ['email', 'fax_number', 'telephone', 'url'])
        end

        def self.feratel_to_image
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('Names', 'Translation', 'text') })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('URL').is_a?(String) ? s.dig('URL') : s.dig('URL', 'text') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('URL').is_a?(String) ? s.dig('URL') : s.dig('URL', 'text') })
          .>> t(:rename_keys, { 'Id' => 'external_key', 'Width' => 'width', 'Height' => 'height', 'Size' => 'content_size', 'Extension' => 'file_format', 'Copyright' => 'caption' })
          .>> t(:map_value, 'width', ->(v) { v.to_i })
          .>> t(:map_value, 'height', ->(v) { v.to_i })
          .>> t(:map_value, 'content_size', ->(v) { v.to_i })
          .>> t(:reject_keys, ['Type', 'Class', 'Systems', 'Order', 'ShowFrom', 'ShowTo', 'ChangeDate', 'Systems', 'Systems', 'Names'])
          .>> t(:strip_all)
        end

        def self.feratel_event_location_to_place
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('Company', 'text') || [s.dig('Title', 'text'), s.dig('LastName', 'text'), s.dig('FirstName', 'text')].flatten.join('') })
          .>> t(:add_field, 'description', ->(s) { s.dig('Company', 'text').present? ? [s.dig('Title', 'text'), s.dig('LastName', 'text'), s.dig('FirstName', 'text')].flatten.join('') : nil })
          .>> t(:rename_keys, { 'Id' => 'external_key' })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('AddressLine1', 'text') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('Country', 'text') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('ZipCode', 'text') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('Town', 'text') })
          .>> t(:nest, 'address', ['street_address', 'address_country', 'address_locality', 'postal_code'])
          .>> t(:rename_keys, 'Latitude' => 'latitude', 'Longitude' => 'longitude')
          .>> t(:map_value, 'latitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:map_value, 'longitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:location)
          .>> t(:reject_keys, ['Type', 'ChangeDate', 'Company', 'AddressLine1', 'Country', 'ZipCode', 'Town'])
          .>> t(:reject_keys, ['Type', 'ChangeDate', 'Company', 'AddressLine1', 'Country', 'ZipCode', 'Town'])
          .>> t(:strip_all)
        end

        def self.feratel_to_event(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:unwrap, 'Details')
          .>> t(:rename_keys, 'Id' => 'external_key', 'Names' => 'name')
          .>> t(:unwrap_description, ['EventHeader'])
          .>> t(:add_field, 'description', ->(v) { ActionController::Base.helpers.simple_format(v&.dig('EventHeader')) if v&.dig('EventHeader').present? })
          .>> t(:add_field, 'feratel_documents', ->(s) { s.dig('Documents', 'Document').is_a?(Hash) ? [s.dig('Documents', 'Document')] : s.dig('Documents', 'Document') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id,
                document_filter(document_classes: ['Image'], document_types: ['EventHeader']))
          .>> t(:add_field, 'feratel_locations', ->(s) { s.dig('Addresses', 'Address').is_a?(Hash) ? [s.dig('Addresses', 'Address')] : s.dig('Addresses', 'Address') })
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { s.dig('feratel_locations')&.detect { |item| item.dig('Type') == 'Venue' }&.dig('Id') })
          .>> t(:add_field, 'event_schedule', ->(s) { load_event_schedules(s) })
          .>> t(:add_field, 'feratel_event_tags', ->(s) { load_feratel_event_tags([s.dig('Visibility'), (s.dig('IsTopEvent') == 'true' ? 'Top-Event' : nil)]) })
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('HolidayThemes', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:reject_keys, ['Systems', '_Type', 'ChangeDate', 'Addresses', 'Documents', 'feratel_documents', 'Facilities', 'CustomAttributes', 'Location', 'Towns', 'Position'])
          .>> t(:strip_all)
        end

        def self.feratel_to_infrastructure(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:unwrap, 'Details')
          .>> t(:rename_keys, 'Id' => 'external_key', 'Names' => 'name')
          .>> t(:unwrap_description, ['InfrastructureLong', 'InfrastructureShort', 'InfrastructurePriceInfo'])
          .>> t(:add_field, 'description', ->(v) { ActionController::Base.helpers.simple_format(v&.dig('InfrastructureShort')) if v&.dig('InfrastructureShort').present? })
          .>> t(:add_field, 'text', ->(v) { ActionController::Base.helpers.simple_format(v&.dig('InfrastructureLong')) if v&.dig('InfrastructureLong').present? })
          .>> t(:add_field, 'price_range', ->(v) { ActionController::Base.helpers.simple_format(v&.dig('InfrastructurePriceInfo')) if v&.dig('InfrastructurePriceInfo').present? })
          .>> t(:unwrap_address, 'InfrastructureExternal')
          .>> t(:unwrap, 'Address', ['AddressLine1', 'Town', 'ZipCode', 'Country', 'Fax', 'Phone', 'Email', 'URL'])
          .>> t(
            :rename_keys,
            {
              'AddressLine1' => 'street_address',
              'Town' => 'address_locality',
              'ZipCode' => 'postal_code',
              'Country' => 'address_country',
              'Fax' => 'fax_number',
              'Phone' => 'telephone',
              'Email' => 'email',
              'URL' => 'url'
            }
          )
          .>> t(:nest, 'address', ['street_address', 'address_locality', 'address_country', 'postal_code'])
          .>> t(:nest, 'contact_info', ['telephone', 'fax_number', 'email', 'url'])
          .>> t(:unwrap, 'Position')
          .>> t(:rename_keys, 'Latitude' => 'latitude', 'Longitude' => 'longitude')
          .>> t(:map_value, 'latitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:map_value, 'longitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:location)
          .>> t(:add_field, 'opening_hours_specification', ->(s) { parse_opening_hours(s.dig('OpeningHours', 'OpeningHour')) })
          .>> t(:add_field, 'feratel_documents', ->(s) { s.dig('Documents', 'Document').is_a?(Hash) ? [s.dig('Documents', 'Document')] : s.dig('Documents', 'Document') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id,
                document_filter(document_classes: ['Image'], document_types: ['Infrastructure']))
          .>> t(:add_links, 'logo', DataCycleCore::Thing, external_source_id,
                document_filter(document_classes: ['Image'], document_types: ['InfrastructureLogo']))
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('HolidayThemes', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('DataOwner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('DataOwner')).hexdigest}"] : [] })
          .>> t(:add_links, 'feratel_topics', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Topics', 'Topic')]&.flatten&.map { |item| item&.dig('Id') } || [] })
          .>> t(:add_links, 'feratel_locations', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Towns', 'Item')]&.flatten&.map { |item| item&.dig('Id') } || [] })
          .>> t(:load_category, 'feratel_types', external_source_id, ->(v) { 'Feratel - Infrastrukturtyp - ' + v&.dig('Topics', 'Type').to_s })
          .>> t(:reject_keys, ['Links', 'OpeningHours', 'Towns', 'CustomAttributes', 'FoodAndBeverage', 'ConnectedEntries', 'HolidayThemes', 'DataOwner', 'Active', 'Address', 'Topics', 'ChangeDate', 'Systems', '_Type'])
          .>> t(:strip_all)
        end

        def self.parse_opening_hours(data)
          return nil if data.blank?
          data = [data] if data.is_a?(::Hash)
          data.map do |item|
            day_keys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map do |day|
              next unless item&.dig(day) == 'true'
              load_day_of_week_id(day)
            end
            {
              season: {
                valid_from: item.dig('DateFrom'),
                valid_through: item.dig('DateTo')
              },
              time: [
                {
                  opens: item.dig('TimeFrom'),
                  closes: item.dig('TimeTo')
                }
              ],
              validity: {
                valid_from: item.dig('DateFrom'),
                valid_through: item.dig('DateTo')
              },
              opens: item.dig('TimeFrom'),
              closes: item.dig('TimeTo'),
              day_of_week: day_keys.compact
            }.with_indifferent_access
          end
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
          DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Wochentag', day_hash[day])
        end

        def self.document_filter(document_classes: [], document_types: [])
          lambda do |data|
            data&.dig('feratel_documents')
              &.select { |d| document_classes.include?(d['Class']) && document_types.include?(d['Type']) }
              &.sort_by { |item| item['Order'].to_i }
              &.map { |item| item&.dig('Id') } || []
          end
        end

        def self.load_feratel_event_tags(names)
          names.compact.map do |name|
            DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
              .where('classification_tree_labels.name = ?', 'Feratel - Veranstaltungstags')
              .where('classification_aliases.name = ?', name).first!.id
          end
        end

        def self.load_event_schedules(data)
          available_dates = data.dig('Dates', 'Date').is_a?(Hash) ? [data.dig('Dates', 'Date')] : data.dig('Dates', 'Date')
          available_start_times = data.dig('StartTimes', 'StartTime').is_a?(Hash) ? [data.dig('StartTimes', 'StartTime')] : data.dig('StartTimes', 'StartTime')
          duration = event_duration(data.dig('Duration', 'Type'), data.dig('Duration', 'text'))

          res = []
          return nil if available_dates.blank?

          available_dates.each do |date|
            start_date = date['From']
            end_date = date['To']
            if available_start_times.present?
              available_start_times.each do |time_items|
                start_time = time_items['Time'].to_datetime
                active_days = time_items.except('Time').select { |_day, val| val == 'true' }.map do |key, _val|
                  load_day_of_week_id(key)
                end&.reject(&:blank?)
                end_time = duration ? (start_time + duration.minutes).strftime('%H:%M') : nil

                time_res = {
                  event_date: {
                    start_date: start_date,
                    end_date: end_date
                  },
                  event_time: {
                    start_time: start_time&.strftime('%H:%M'),
                    end_time: end_time
                  },
                  day_of_week: active_days
                }

                res << time_res
              end
            else
              res << {
                event_date: {
                  start_date: start_date,
                  end_date: end_date
                }
              }
            end
          end
          res.flatten.sort_by { |o| o[:event_date][:start_date] }
        end

        def self.event_duration(type, value)
          case type
          when 'None'
            nil
          when 'Day'
            nil
          # value.to_f * 24 * 60
          when 'Hour'
            value.to_f * 60
          when 'Minute'
            value.to_f
          else
            raise "Unkown duration type '#{type}'"
          end
        end
      end
    end
  end
end

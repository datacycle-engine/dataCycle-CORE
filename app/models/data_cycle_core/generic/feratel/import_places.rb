# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportPlaces
        def import_data(**options)
          @image_template = options[:import][:image_template] || 'Bild'

          import_contents(
            method(:load_contents).to_proc,
            method(:process_content).to_proc,
            **options
          )
        end

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, template, locale)
          I18n.with_locale(locale) do
            images = [raw_data.dig('Documents', 'Document')].flatten.reject(&:nil?).select { |d|
              d['Class'] == 'Image'
            }.map do |raw_image_data|
              create_or_update_content(
                DataCycleCore::CreativeWork,
                load_template(DataCycleCore::CreativeWork, @image_template),
                extract_image_data(raw_image_data).with_indifferent_access
              )
            end

            topics = [raw_data.dig('Details', 'Topics', 'Topic')].flatten.reject(&:nil?).map { |t|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: t['Id'].downcase)
            }.reject(&:nil?)

            holiday_themes = [raw_data.dig('Details', 'HolidayThemes', 'Item')].flatten.reject(&:nil?).map { |t|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: t['Id'].downcase)
            }.reject(&:nil?)

            facilities = [raw_data.dig('Facilities', 'Facility')].flatten.reject(&:nil?).map { |f|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: f['Id'].downcase)
            }.reject(&:nil?)

            accommodation_categories = [raw_data.dig('Details', 'Categories', 'Item')].flatten.reject(&:nil?).map { |c|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: c['Id'].downcase)
            }.reject(&:nil?)

            feratel_classifications = [raw_data.dig('Details', 'Classifications', 'Item')].flatten.reject(&:nil?).map { |c|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: c['Id'].downcase)
            }.reject(&:nil?)

            stars = [raw_data.dig('Details', 'Stars')].flatten.reject(&:nil?).map { |s|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: s['Id'].downcase)
            }.reject(&:nil?)

            owners = [raw_data.dig('Details', 'DataOwner')].flatten.reject(&:nil?).map { |s|
              DataCycleCore::Classification.find_by(external_source_id: external_source.id,
                                                    external_key: "OWNER:#{Digest::MD5.hexdigest(s.is_a?(String) ? s : s['text'])}")
            }.reject(&:nil?)

            create_or_update_content(
              @target_type,
              load_template(@target_type, @data_template),
              extract_place_data(raw_data).with_indifferent_access.merge(
                data_type: nil,
                image: images.map(&:id),
                topics: topics.map(&:id),
                holiday_themes: holiday_themes.map(&:id),
                facilities: facilities.map(&:id),
                accommodation_categories: accommodation_categories.map(&:id),
                feratel_classifications: feratel_classifications.map(&:id),
                stars: stars.map(&:id),
                feratel_owners: owners.map(&:id)
              ).with_indifferent_access
            )
          end
        end

        def extract_image_data(raw_data)
          {
            external_key: raw_data['Id'],
            headline: raw_data.dig('Names', 'Translation', 'text'),
            thumbnail_url: raw_data.dig('URL').is_a?(String) ? raw_data.dig('URL') : raw_data.dig('URL', 'text'),
            content_url: raw_data.dig('URL').is_a?(String) ? raw_data.dig('URL') : raw_data.dig('URL', 'text')
          }
        end

        def extract_place_data(raw_data)
          return {} if raw_data.nil?

          place_transformation.call(raw_data)
        end

        def place_transformation
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
            .>> t(:flatten_translations)
            .>> t(:flatten_texts)
            .>> t(:unwrap, 'Details')
            .>> t(:rename_keys,
                  'Id' => 'external_key',
                  'Names' => 'name')
            .>> t(:unwrap, 'Position')
            .>> t(:rename_keys,
                  'Latitude' => 'latitude',
                  'Longitude' => 'longitude')
            .>> t(:map_value, 'latitude', ->(v) { v.to_f })
            .>> t(:map_value, 'longitude', ->(v) { v.to_f })
            .>> t(:location)
            .>> t(:unwrap_description, 'ServiceProviderDescription')
            .>> t(:rename_keys, 'ServiceProviderDescription' => 'description')
            .>> t(:reject_keys, ['Town'])
            .>> t(:unwrap_address, 'Object')
            .>> t(:unwrap, 'Address')
            .>> t(:rename_keys,
                  'AddressLine1' => 'street_address',
                  'Town' => 'address_locality',
                  'ZipCode' => 'postal_code',
                  'Country' => 'address_country',
                  'Fax' => 'fax_number',
                  'Phone' => 'telephone',
                  'Email' => 'email',
                  'URL' => 'url')
            .>> t(:map_value, 'url', ->(s) { s.nil? ? '' : (!s.starts_with?('http://') && !s.starts_with?('https://') ? "http://#{s}" : s) })
            .>> t(:nest, 'address', ['street_address', 'address_country', 'address_locality', 'postal_code'])
            .>> t(:nest, 'contact_info', ['email', 'fax_number', 'telephone', 'url'])
        end

        # def extract_place_data(raw_data)
        #   return {} if raw_data.nil?
        #
        #   short_description = [raw_data.dig('Descriptions', 'Description')].flatten.reject(&:nil?).find { |d|
        #     d['Type'] == 'InfrastructureShort' || d['Type'] == 'ServiceProviderDescription'
        #   }
        #   long_description = [raw_data.dig('Descriptions', 'Description')].flatten.reject(&:nil?).find { |d|
        #     d['Type'] == 'InfrastructureLong'
        #   }
        #   hours_available = [raw_data.dig('Descriptions', 'Description')].flatten.reject(&:nil?).find { |d|
        #     d['Type'] == 'InfrastructureOpeningTimes'
        #   }
        #
        #   address = [raw_data.dig('Addresses', 'Address')].flatten.reject(&:nil?).find { |d|
        #     d['Type'] == 'InfrastructureExternal' || d['Type'] == 'Object'
        #   }
        #
        #   if raw_data.dig('Details', 'Position', 'Latitude').to_i != 0 &&
        #      raw_data.dig('Details', 'Position', 'Longitude').to_i != 0
        #     {
        #       external_key: raw_data['Id'],
        #       name: raw_data['Details']['Names']['Translation']['text'],
        #       description: (short_description || {}).dig('text').try(:gsub, /\n/, '<br />'),
        #       text: (long_description || {}).dig('text').try(:gsub, /\n/, '<br />'),
        #       hours_available: (hours_available || {}).dig('text').try(:gsub, /\n/, '<br />'),
        #       street_address: [
        #         address.try(:dig, 'AddressLine1', 'text'),
        #         address.try(:dig, 'AddressLine2', 'text')
        #       ].reject(&:blank?).join("\n"),
        #       address_locality: address.try(:dig, 'Town', 'text'),
        #       postal_code: address.try(:dig, 'ZipCode', 'text'),
        #       fax_number: address.try(:dig, 'Fax', 'text'),
        #       telephone: address.try(:dig, 'Phone', 'text'),
        #       email: address.try(:dig, 'Email', 'text'),
        #       url: address.try(:dig, 'URL', 'text'),
        #       latitude: raw_data.dig('Details', 'Position', 'Latitude').to_f,
        #       longitude: raw_data.dig('Details', 'Position', 'Longitude').to_f,
        #       location: DataCycleCore::Generic::Transformations::Functions.location({
        #         'latitude' => raw_data.dig('Details', 'Position', 'Latitude').to_f,
        #         'longitude' => raw_data.dig('Details', 'Position', 'Longitude').to_f,
        #       })['location']
        #     }
        #   else
        #     {
        #       external_key: raw_data['Id'],
        #       name: raw_data['Details']['Names']['Translation']['text'],
        #       description: (short_description || {}).dig('text').try(:gsub, /\n/, '<br />'),
        #       text: (long_description || {}).dig('text').try(:gsub, /\n/, '<br />'),
        #       hours_available: (hours_available || {}).dig('text').try(:gsub, /\n/, '<br />'),
        #       street_address: [
        #         address.try(:dig, 'AddressLine1', 'text'),
        #         address.try(:dig, 'AddressLine2', 'text')
        #       ].reject(&:blank?).join("\n"),
        #       address_locality: address.try(:dig, 'Town', 'text'),
        #       postal_code: address.try(:dig, 'ZipCode', 'text'),
        #       fax_number: address.try(:dig, 'Fax', 'text'),
        #       telephone: address.try(:dig, 'Phone', 'text'),
        #       email: address.try(:dig, 'Email', 'text'),
        #       url: address.try(:dig, 'URL', 'text')
        #     }
        #   end
        # end

        def t(*args)
          DataCycleCore::Generic::Feratel::TransformationFunctions[*args]
        end
      end
    end
  end
end

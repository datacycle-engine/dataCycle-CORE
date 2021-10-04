# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module Processing
        def self.process_image(utility_object, raw_data, config)
          template = config&.dig(:template) || 'Bild'

          ([raw_data.dig('Documents', 'Document')].flatten.reject(&:nil?).select { |d|
            d['Class'] == 'Image'
          }.each do |image_hash|
            if image_hash.dig('CCAuthor')&.strip.present?
              DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
                utility_object: utility_object,
                template: DataCycleCore::Generic::Common::ImportFunctions.load_template('Organization'),
                data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
                  config,
                  {
                    'name' => image_hash.dig('CCAuthor').strip,
                    external_key: DataCycleCore::MasterData::DataConverter.string_to_string("CCAuthor: #{image_hash.dig('CCAuthor').strip}"),
                    external_source_id: utility_object.external_source.id
                  }
                ).with_indifferent_access
              )
            end
            DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
              utility_object: utility_object,
              template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
              data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
                config,
                DataCycleCore::Generic::Feratel::Transformations.feratel_to_image(utility_object.external_source.id).call(image_hash)
              ).with_indifferent_access
            )
          end
          )
        end

        def self.process_event_location(utility_object, raw_data, config)
          template = config&.dig(:template) || 'POI'
          place_hash = [
            Array.wrap(raw_data.dig('Addresses', 'Address'))&.select { |d| d['Type'] == 'Venue' }&.first,
            raw_data.dig('Details', 'Location').present? ? { 'Location' => raw_data.dig('Details', 'Location') } : nil,
            raw_data.dig('Details', 'Position').present? ? { 'Position' => raw_data.dig('Details', 'Position') } : nil
          ].reject(&:blank?).reduce({}, :merge)

          # binding.pry if raw_data.dig('Addresses', 'Address').blank?

          return if [
            place_hash.dig('Location', 'Translation', 'text'),
            place_hash.dig('Company', 'text'),
            place_hash.dig('FirstName', 'text'), place_hash.dig('LastName', 'text')
          ].reject(&:blank?).empty?

          place_hash['Id'] = "Location:#{raw_data.dig('Id')}"

          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: place_hash,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_event_location_to_place,
            default: { template: template },
            config: config
          )
        end

        def self.process_event(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_event(utility_object.external_source.id),
            default: { template: 'Event' },
            config: config
          )
        end

        def self.process_serial_event(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_serial_event(utility_object.external_source.id),
            default: { template: 'Eventserie' },
            config: config
          )
        end

        def self.process_brochure(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.to_brochure(utility_object.external_source.id),
            default: { template: 'Katalog' },
            config: config
          )
        end

        def self.process_room(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_room(utility_object.external_source.id),
            default: { template: 'Zimmer' },
            config: config
          )
        end

        def self.process_additional_service(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_additional_service(utility_object.external_source.id),
            default: { template: 'Zimmer' },
            config: config
          )
        end

        def self.process_accommodation(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_accommodation(utility_object.external_source.id),
            default: { template: 'Unterkunft' },
            config: config
          )
        end

        def self.process_package(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_aggregate_offer(utility_object.external_source.id),
            default: { template: 'Pauschalangebot' },
            config: config
          )
        end

        def self.process_package_place(utility_object, raw_data, config)
          return if raw_data&.dig('Details', 'Position').blank?
          return if raw_data&.dig('Details', 'Position', 'Latitude').blank? || raw_data&.dig('Details', 'Position', 'Latitude')&.to_f&.zero?
          return if raw_data&.dig('Details', 'Position', 'Longitude').blank? || raw_data&.dig('Details', 'Position', 'Longitude')&.to_f&.zero?

          place_data = raw_data.dig('Details', 'Position')
          place_data['place_id'] = "PackagePlace:#{raw_data.dig('Id')}"

          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: place_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_package_place,
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end

        def self.process_infrastructure(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_infrastructure(utility_object.external_source.id),
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_asp(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.to_local_business(utility_object.external_source.id),
            default: { template: 'LocalBusiness' },
            config: config
          )
        end

        def self.process_as(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.to_additional_service(utility_object.external_source.id),
            default: { template: 'Service' },
            config: config
          )
        end

        def self.process_meeting_point(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.to_meeting_point,
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end

        def self.process_landlord(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.to_landlord(utility_object.external_source.id),
            default: { template: 'Organization' },
            config: config
          )
        end

        def self.process_organizer(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.to_organizer,
            default: { template: 'Organization' },
            config: config
          )
        end
      end
    end
  end
end

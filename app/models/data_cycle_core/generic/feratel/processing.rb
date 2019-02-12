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
            DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
              utility_object: utility_object,
              template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
              data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
                config,
                DataCycleCore::Generic::Feratel::Transformations
                .feratel_to_image
                .call(image_hash)
              ).with_indifferent_access
            )
          end
          )
        end

        def self.process_event_location(utility_object, raw_data, config)
          template = config&.dig(:template) || 'Örtlichkeit'

          address = raw_data.dig('Addresses', 'Address')&.select do |d|
            d['Type'] == 'Venue'
          end&.first&.merge(raw_data.dig('Details', 'Position'))

          return if address.blank?

          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: address,
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
            default: { template: 'dataCycleEvent' },
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

        def self.process_infrastructure(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_infrastructure(utility_object.external_source.id),
            default: { template: 'POI' },
            config: config
          )
        end
      end
    end
  end
end

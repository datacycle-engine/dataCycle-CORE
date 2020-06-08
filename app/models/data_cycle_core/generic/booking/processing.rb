# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Booking
      module Processing
        def self.process_image(utility_object, raw_data, config)
          template = config&.dig(:template) || 'Bild'

          (raw_data.dig('hotel_data', 'hotel_photos') || []).each do |image_hash|
            DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
              utility_object: utility_object,
              template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
              data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
                config,
                DataCycleCore::Generic::Booking::Transformations
                .booking_to_image(raw_data.dig('hotel_data', 'name'), utility_object.external_source.id)
                .call(image_hash)
              ).with_indifferent_access
            )
          end
        end

        def self.process_hotel(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Booking::Transformations.booking_to_unterkunft(utility_object.external_source.id),
            default: { template: 'Unterkunft' },
            config: config
          )
        end
      end
    end
  end
end

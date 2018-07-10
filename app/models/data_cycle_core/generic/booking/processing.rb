# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Booking
      module Processing
        def self.process_hotel(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Booking::Transformations.booking_to_unterkunft(utility_object.external_source.id),
            default: { content_type: DataCycleCore::Place, template: 'Unterkunft' },
            config: config
          )
        end
      end
    end
  end
end

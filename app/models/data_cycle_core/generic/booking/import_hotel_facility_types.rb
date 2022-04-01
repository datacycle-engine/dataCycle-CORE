# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Booking
      module ImportHotelFacilityTypes
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label) || 'Booking.com - FacilityTypes',
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(_mongo_item, locale, _options)
          DataCycleCore::Classification
            .where("external_key ILIKE 'Booking.com - FacilityTypes - %'")
            .map { |item|
              {
                'hotel_facility_type_id' => item.external_key.split(' - ').last&.to_i,
                'facility_type_id' => 0,
                'root' => true,
                'translations' => [{ 'name' => item.primary_classification_alias.name }]
              }
            }.map { |data| { 'dump' => { locale.to_s => data } }.with_indifferent_access }
        end

        def self.load_child_classifications(mongo_item, parent_data, locale = 'de')
          return [] unless parent_data.dig('root')
          mongo_item.where("dump.#{locale}.facility_type_id": parent_data.dig('hotel_facility_type_id'))
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: "Booking.com - FacilityTypes - #{raw_data.dig('facility_type_id')}"
            )
            .try(:primary_classification_alias)
        end

        def self.extract_data(_options, raw_data)
          prefix = raw_data.dig('facility_type_id').zero? ? 'Booking.com - FacilityTypes - ' : 'Booking.com - HotelFacilityTypes - '
          {
            external_key: prefix + raw_data.dig('hotel_facility_type_id').to_s,
            name: raw_data.dig('translations', 0, 'name')
          }
        end
      end
    end
  end
end

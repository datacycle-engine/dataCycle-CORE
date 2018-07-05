# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Booking
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.booking_to_unterkunft(external_source_id)
          t(:stringify_keys)
          .>> t(:reject_keys, ['region'])
          .>> t(:rename_keys, { 'hotel_id' => 'external_key' })
          .>> t(:unwrap, 'hotel_data', ['name', 'hotel_description', 'hotel_important_information'])
          .>> t(:rename_keys, { 'name' => 'title', 'hotel_description' => 'description', 'hotel_important_information' => 'text' })
          .>> t(:unwrap, 'hotel_data', ['address', 'city', 'zip', 'country'])
          .>> t(:rename_keys, { 'address' => 'street_address', 'zip' => 'postal_code', 'city' => 'address_locality', 'country' => 'address_country' })
          .>> t(:map_value, 'address_country', ->(s) { s&.upcase })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_field, 'longitude', ->(s) { s.dig('hotel_data', 'location', 'longitude')&.to_f })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('hotel_data', 'location', 'latitude')&.to_f })
          .>> t(:location)
          .>> t(:load_category_key, 'booking_hotel_types', external_source_id, ->(s) { 'Booking.com - HotelTypes - ' + s&.dig('hotel_data', 'hotel_type_id').to_s })
          .>> t(:add_field, 'booking_hotel_facility_types', ->(s) { load_hotel_facilities(s&.dig('hotel_data', 'hotel_facilities'), external_source_id) })
          .>> t(:reject_keys, ['hotel_data'])
          .>> t(:strip_all)
        end

        def self.load_hotel_facilities(facilities, external_source_id)
          return if facilities.blank?
          DataCycleCore::Classification.where(
            external_source_id: external_source_id,
            external_key: facilities.map { |data| 'Booking.com - HotelFacilityTypes - ' + data['hotel_facility_type_id'].to_s }
          ).ids
        end
      end
    end
  end
end

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
          .>> t(:rename_keys, { 'hotel_description' => 'description', 'hotel_important_information' => 'text' })
          .>> t(:unwrap, 'hotel_data', ['url'])
          .>> t(:rename_keys, { 'url' => 'booking_url' })
          .>> t(:unwrap, 'hotel_data', ['address', 'city', 'zip', 'country'])
          .>> t(:rename_keys, { 'address' => 'street_address', 'zip' => 'postal_code', 'city' => 'address_locality', 'country' => 'address_country' })
          .>> t(:map_value, 'address_country', ->(s) { s&.upcase })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_field, 'longitude', ->(s) { s.dig('hotel_data', 'location', 'longitude')&.to_f })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('hotel_data', 'location', 'latitude')&.to_f })
          .>> t(:location)
          .>> t(:load_category_key, 'booking_hotel_types', external_source_id, ->(s) { 'Booking.com - HotelTypes - ' + s&.dig('hotel_data', 'hotel_type_id').to_s })
          .>> t(:add_field, 'booking_hotel_facility_types', ->(s) { load_hotel_facilities(s&.dig('hotel_data', 'hotel_facilities'), external_source_id) })
          .>> t(:add_links, 'image', DataCycleCore::CreativeWork, external_source_id, ->(s) { s&.dig('hotel_data', 'hotel_photos')&.map { |item| item.dig('url_original').split('/').last } || [] })
          .>> t(:reject_keys, ['hotel_data'])
          .>> t(:strip_all)
        end

        def self.booking_to_image(name, external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'headline', ->(_s) { name })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('url_original').split('/').last })
          .>> t(:rename_keys, { 'url_original' => 'content_url', 'url_max300' => 'thumbnail_url', 'tags' => 'keywords_booking' })
          .>> t(:reject_keys, ['main_photo', 'is_logo_photo', 'url_square60'])
          .>> t(:tags_to_ids, 'keywords_booking', external_source_id, 'Booking.com - Tag - ')
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

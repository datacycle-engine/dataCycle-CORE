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
          .>> t(:add_field, 'additional_information_hotel', ->(s) { Array.wrap(to_additional_information(external_source_id, 'hotel_description').call(s).compact) if s.dig('hotel_data', 'hotel_description')&.squish.present? })
          .>> t(:add_field, 'additional_information', ->(s) { Array.wrap(to_additional_information(external_source_id, 'hotel_important_information').call(s).compact) if s.dig('hotel_data', 'hotel_important_information')&.squish.present? })
          .>> t(:merge_array_values, 'additional_information', 'additional_information_hotel')
          .>> t(:add_field, 'universal_classifications', ->(s) { Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Booking.com - ExactClass', s.dig('hotel_data', 'exact_class').to_s)).compact })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('hotel_id').to_s })
          .>> t(:unwrap, 'hotel_data', ['name', 'hotel_description'])
          .>> t(:rename_keys, { 'hotel_description' => 'description' })
          .>> t(:unwrap, 'hotel_data', ['url'])
          .>> t(:rename_keys, { 'url' => 'booking_url' })
          .>> t(:unwrap, 'hotel_data', ['address', 'city', 'zip', 'country'])
          .>> t(:rename_keys, { 'address' => 'street_address', 'zip' => 'postal_code', 'city' => 'address_locality', 'country' => 'address_country' })
          .>> t(:map_value, 'address_country', ->(s) { s&.upcase })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_field, 'longitude', ->(s) { s.dig('hotel_data', 'location', 'longitude')&.to_f })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('hotel_data', 'location', 'latitude')&.to_f })
          .>> t(:location)
          .>> t(:add_field, 'price_range', ->(s) { parse_min_price(s.dig('room_data')) })
          .>> t(:add_field, 'aggregate_rating', ->(s) { parse_rating(s) })
          .>> t(:load_category, 'booking_hotel_types', external_source_id, ->(s) { 'Booking.com - HotelTypes - ' + s&.dig('hotel_data', 'hotel_type_id').to_s })
          .>> t(:add_field, 'booking_hotel_facility_types', ->(s) { load_hotel_facilities(s&.dig('hotel_data', 'hotel_facilities'), external_source_id) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('hotel_data', 'hotel_photos')&.map { |item| item.dig('url_original').split('/').last } || [] })
          .>> t(:reject_keys, ['hotel_data', 'room_data'])
          .>> t(:strip_all)
        end

        def self.booking_to_image(name, external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(*) { name })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('url_original').split('/').last })
          .>> t(:rename_keys, { 'url_original' => 'content_url', 'url_max300' => 'thumbnail_url', 'tags' => 'keywords_booking' })
          .>> t(:reject_keys, ['main_photo', 'is_logo_photo', 'url_square60'])
          .>> t(:tags_to_ids, 'keywords_booking', external_source_id, 'Booking.com - Tag - ')
          .>> t(:strip_all)
        end

        def self.to_additional_information(external_source_id, type)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Booking - additional_information - #{I18n.locale} - #{type} - #{s.dig('hotel_id')}" })
          .>> t(:add_field, 'id', ->(s) { DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: s.dig('external_key'))&.id })
          .>> t(:add_field, 'name', ->(*) { I18n.t("import.booking.#{type}", default: [type]) })
          .>> t(:add_field, 'universal_classifications', ->(*) { Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', type)) })
          .>> t(:add_field, 'description', ->(s) { s.dig('hotel_data', type) })
          .>> t(:reject_keys, ['room_data', 'hotel_id', 'hotel_data'])
          .>> t(:strip_all)
        end

        def self.load_hotel_facilities(facilities, external_source_id)
          return if facilities.blank?
          DataCycleCore::Classification.where(
            external_source_id: external_source_id,
            external_key: facilities.map { |data| 'Booking.com - HotelFacilityTypes - ' + data['hotel_facility_type_id'].to_s }
          ).ids
        end

        def self.parse_rating(s)
          return [] if s.dig('hotel_data', 'number_of_reviews').blank? || s.dig('hotel_data', 'review_score').blank?
          [{ 'rating_count' => s.dig('hotel_data', 'number_of_reviews')&.to_i,
             'rating_value' => s.dig('hotel_data', 'review_score')&.to_f }]
        end

        def self.parse_min_price(s)
          return if s.blank?
          price = s.map { |room_data| room_data.dig('room_info', 'min_price')&.to_f }
            .compact
            .select(&:positive?)
            .min
          "ab € #{price}" if price.present?
        end
      end
    end
  end
end

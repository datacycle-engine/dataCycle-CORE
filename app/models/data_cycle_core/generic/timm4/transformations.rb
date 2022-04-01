# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Timm4
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Timm4::TransformationFunctions[*args]
        end

        def self.to_poi(external_source_id)
          t(:add_info, ['intro', 'description', 'positionDescription', 'pricesDescription', 'keywords'], external_source_id)
          .>> t(:add_images, external_source_id)
          .>> t(:add_opening_hours_specification, external_source_id)
          .>> t(:add_opening_hours_description)
          .>> t(:rename_keys, { 'id' => 'external_key', 'title' => 'name' })
          .>> t(:map_value, 'external_key', ->(v) { "TIMM4 - POI - #{v}" })
          .>> t(:unwrap, 'gps')
          .>> t(:location)
          .>> t(:add_contact_name, 'address')
          .>> t(:add_field, 'email', ->(s) { s.dig('address', 'email') })
          .>> t(:nest, 'contact_info', ['contact_name', 'email'])
          .>> t(:rename_keys, { 'address' => 'given_address' })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('given_address', 'streetAddress') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('given_address', 'postalCode') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('given_address', 'locality') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('given_address', 'country') })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_links, 'timm4_categories', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s['categories'])&.map { |i| "TIMM4 - Pois - Category - #{i}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('timm4_categories') })
        end

        def self.to_gastronomy(external_source_id)
          t(:add_info, ['intro', 'description', 'culinarySpecialities', 'furtherSpecialities', 'dishes', 'barrierFreeDescription', 'restDays', 'companyHoliday'], external_source_id)
          .>> t(:add_images, external_source_id)
          .>> t(:add_opening_hours_specification, external_source_id)
          .>> t(:add_opening_hours_description)
          .>> t(:add_dining_hours_specification, external_source_id)
          .>> t(:add_dining_hours_description)
          .>> t(:rename_keys, { 'id' => 'external_key', 'title' => 'name' })
          .>> t(:map_value, 'external_key', ->(v) { "TIMM4 - Gastronomy - #{v}" })
          .>> t(:add_contact_name)
          .>> t(:add_field, 'email', ->(s) { s.dig('address', 'email') })
          .>> t(:nest, 'contact_info', ['contact_name', 'email'])
          .>> t(:rename_keys, { 'address' => 'given_address' })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('given_address', 'streetAddress') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('given_address', 'postalCode') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('given_address', 'locality') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('given_address', 'country') })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_links, 'timm4_classifications', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s['classifications'])&.map { |i| "TIMM4 - Gastronomy - Classification - #{i}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('timm4_classifications') })
          .>> t(:add_links, 'timm4_equipment', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s['equipmentFeatures'])&.map { |i| "TIMM4 - Gastronomy - Equipment feature - #{i}" } })
          .>> t(:add_potential_action, external_source_id)
          .>> t(:universal_classifications, ->(s) { s.dig('timm4_equipment') })
        end

        def self.to_event(external_source_id)
          t(:add_info, ['description', 'timesComment', 'meetingPoint'], external_source_id)
          .>> t(:add_images, external_source_id)
          .>> t(:add_links, 'organizer', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap("TIMM4 - Organizer - #{s.dig('organizer', 'id')}") }, ->(s) { s.dig('organizer', 'id') })
          .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap("TIMM4 - Event Location - #{s.dig('address', 'id')}") }, ->(s) { s.dig('address', 'id') })
          .>> t(:rename_keys, { 'id' => 'external_key', 'title' => 'name' })
          .>> t(:map_value, 'external_key', ->(v) { "TIMM4 - Event - #{v}" })
          .>> t(:add_url)
          .>> t(:add_links, 'timm4_category', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s['category'])&.map { |i| "TIMM4 - Events - Category - #{i}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('timm4_category') })
          .>> t(:add_links, 'timm4_music_category', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s['musicCategory'])&.map { |i| "TIMM4 - Events - Music category - #{i}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('timm4_music_category') })
          .>> t(:add_schedule, external_source_id, ->(s) { s.dig('external_key') })
        end

        def self.to_tour(external_source_id)
          t(:add_images, external_source_id)
          .>> t(:rename_keys, { 'id' => 'external_key', 'title' => 'name' })
          .>> t(:map_value, 'external_key', ->(v) { "TIMM4 - Track - #{v}" })
          .>> t(:map_value, 'length', ->(v) { v.blank? ? nil : v&.to_f&.*(1000) })
          .>> t(:add_links, 'timm4_localities', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s['localities'])&.map { |i| "TIMM4 - Tracks - Locality - #{i}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('timm4_localities') })
          .>> t(:add_line)
        end

        def self.to_image
          t(:add_field, 'thumbnail_url', ->(s) { s.dig('content_url') })
          .>> t(:add_field, 'url', ->(s) { s.dig('url') })
          .>> t(:add_field, 'name', ->(s) { s.dig('img_description') || s.dig('content_url').split('/').last })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('content_url') })
        end

        def self.to_event_location
          t(
            :rename_keys,
            {
              'id' => 'external_key',
              'organization' => 'name',
              'streetAddress' => 'street_address',
              'postalCode' => 'postal_code',
              'locality' => 'address_locality',
              'country' => 'address_country'
            }
          )
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_contact_name)
          .>> t(:nest, 'contact_info', ['contact_name', 'email'])
          .>> t(:add_location_name)
          .>> t(:map_value, 'external_key', ->(v) { "TIMM4 - Event Location - #{v}" })
        end

        def self.to_organizer
          t(
            :rename_keys,
            {
              'id' => 'external_key',
              'organization' => 'name',
              'streetAddress' => 'street_address',
              'postalCode' => 'postal_code',
              'locality' => 'address_locality',
              'country' => 'address_country'
            }
          )
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:nest, 'contact_info', ['email'])
          .>> t(:map_value, 'external_key', ->(v) { "TIMM4 - Organizer - #{v}" })
        end
      end
    end
  end
end

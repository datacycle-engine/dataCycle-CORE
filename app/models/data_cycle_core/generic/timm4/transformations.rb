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
          .>> t(:add_contact_name)
          .>> t(:add_field, 'email', ->(s) { s.dig('address', 'email') })
          .>> t(:nest, 'contact_info', ['contact_name', 'email'])
          .>> t(:rename_keys, { 'address' => 'given_address' })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('given_address', 'streetAddress') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('given_address', 'postalCode') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('given_address', 'locality') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('given_address', 'country') })
          .>> t(:add_links, 'timm4_categories', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s['categories'])&.map { |i| "TIMM4 - Pois - Category - #{i}" } })
          .>> t(:universal_classifications, ->(s) { s.dig('timm4_categories') })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
        end

        def self.to_image
          t(:add_field, 'thumbnail_url', ->(s) { s.dig('content_url') })
          .>> t(:add_field, 'url', ->(s) { s.dig('url') })
          .>> t(:add_field, 'name', ->(s) { s.dig('img_description') || s.dig('content_url').split('/').last })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('content_url') })
        end
      end
    end
  end
end

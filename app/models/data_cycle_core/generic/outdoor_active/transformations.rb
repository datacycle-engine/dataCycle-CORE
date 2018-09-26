# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.outdoor_active_to_place(external_source_id)
          t(:stringify_keys)
          .>> t(
            :rename_keys,
            {
              'id' => 'external_key',
              'title' => 'name',
              'shortText' => 'description',
              'longText' => 'text',
              'altitude' => 'elevation',
              'fax' => 'fax_number',
              'phone' => 'telephone',
              'homepage' => 'url',
              'businessHours' => 'hours_available',
              'fee' => 'price',
              'gettingThere' => 'directions'
            }
          )
          .>> t(:map_value, 'elevation', ->(s) { s.try(:to_f) })
          .>> t(:add_field, 'latitude', ->(s) { s['geometry'].try(:split, /[, ]/, 3).try(:[], 1).try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s['geometry'].try(:split, /[, ]/, 3).try(:[], 0).try(:to_f) })
          .>> t(:location)
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('address', 'town') })
          .>> t(:add_field, 'street_address', ->(s) { [s.dig('address', 'street')&.strip, s.dig('address', 'housenumber')&.strip].join(' ') if s.dig('address', 'street')&.strip.present? })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('address', 'zipcode') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('address', 'countryname') })
          .>> t(:reject_keys, ['address'])
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_country', 'address_locality'])
          .>> t(:nest, 'contact_info', ['telephone', 'fax_number', 'url', 'email'])
          .>> t(:add_field, 'author', ->(s) { s.dig('meta', 'author') })
          .>> t(:add_links, 'image', DataCycleCore::CreativeWork, external_source_id, ->(s) { s&.dig('images', 'image')&.map { |item| item&.dig('id') } || [] })
          .>> t(:add_links, 'primary_image', DataCycleCore::CreativeWork, external_source_id, ->(s) { s&.dig('primaryImage')&.dig('id') })
          .>> t(:add_links, 'regions', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('regions', 'region')&.map { |item| "REGION:#{item&.dig('id')}" } || [] })
          .>> t(:add_links, 'source', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('meta', 'source', 'id').present? ? ["SOURCE:#{s&.dig('meta', 'source', 'id')}"] : [] })
          .>> t(:load_category_key, 'poi_categories', external_source_id, ->(s) { s&.dig('category', 'id').present? ? "CATEGORY:#{s&.dig('category', 'id')}" : nil })
          .>> t(:load_category, 'frontend_type', ->(s) { s&.dig('frontendtype').presence }, external_source_id, ->(s) { s&.dig('frontendtype').present? ? "FRONTENDTYPE:#{Digest::MD5.new.update(s.dig('frontendtype')).hexdigest}" : nil })
          .>> t(:category_key_to_ids, 'outdoor_active_tags', ->(s) { s&.dig('properties', 'property') }, 'text', external_source_id, 'TAG:', 'tag')
          .>> t(:reject_keys, ['category', 'primaryImage', 'images', 'regions', 'meta'])
          .>> t(:strip_all)
        end

        def self.outdoor_active_to_tour(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'latitude', ->(s) { s.dig('startingPoint', 'lon')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('startingPoint', 'lat')&.to_f })
          .>> t(:add_field, 'start_location', ->(s) { RGeo::Geographic.spherical_factory(srid: 4326).point(s['latitude'], s['longitude']) if s['longitude'] && s['latitude'] })
          .>> t(:add_field, 'tour', ->(s) { tour(s&.dig('geometry')) })
          .>> t(:unwrap, 'elevation', ['ascent', 'descent', 'minAltitude', 'maxAltitude'])
          .>> t(:unwrap, 'time', ['min'])
          .>> t(:unwrap, 'rating', ['condition', 'difficulty', 'experience', 'landscape'])
          .>> t(:add_field, 'author', ->(s) { s.dig('meta', 'author') })
          .>> t(
            :rename_keys,
            {
              'id' => 'external_key',
              'title' => 'name',
              'shortText' => 'description',
              'longText' => 'text',
              'altitude' => 'elevation',
              'minAltitude' => 'min_altitude',
              'maxAltitude' => 'max_altitude',
              'min' => 'duration',
              'condition' => 'condition_rating',
              'difficulty' => 'difficulty_rating',
              'experience' => 'experience_rating',
              'landscape' => 'landscape_rating',
              'directions' => 'instructions',
              'gettingThere' => 'directions',
              'publicTransit' => 'directions_public_transport',
              'safetyGuidelines' => 'safety_instructions',
              'tip' => 'suggestion',
              'additionalInformation' => 'additional_information'
            }
          )
          .>> t(:map_value, 'elevation', ->(s) { s&.to_f })
          .>> t(:map_value, 'length', ->(s) { s&.to_f })
          .>> t(:map_value, 'duration', ->(s) { s&.to_i })
          .>> t(:map_value, 'condition_rating', ->(s) { s&.to_i })
          .>> t(:map_value, 'difficulty_rating', ->(s) { s&.to_i })
          .>> t(:map_value, 'experience_rating', ->(s) { s&.to_i })
          .>> t(:map_value, 'landscape_rating', ->(s) { s&.to_i })
          .>> t(:add_links, 'image', DataCycleCore::CreativeWork, external_source_id, ->(s) { s&.dig('images', 'image')&.map { |item| item&.dig('id') } || [] })
          .>> t(:load_category_key, 'tour_categories', external_source_id, ->(s) { s&.dig('category', 'id').present? ? "CATEGORY:#{s&.dig('category', 'id')}" : nil })
          .>> t(:load_category, 'frontend_type', ->(s) { s&.dig('frontendtype').presence }, external_source_id, ->(s) { s&.dig('frontendtype').present? ? "FRONTENDTYPE:#{Digest::MD5.new.update(s.dig('frontendtype')).hexdigest}" : nil })
          .>> t(:category_key_to_ids, 'outdoor_active_tags', ->(s) { s&.dig('properties', 'property') }, 'text', external_source_id, 'TAG:', 'tag')
          .>> t(:add_links, 'regions', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('regions', 'region')&.map { |item| "REGION:#{item&.dig('id')}" } || [] })
          .>> t(:add_links, 'source', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('meta', 'source', 'id').present? ? ["SOURCE:#{s&.dig('meta', 'source', 'id')}"] : nil })
          .>> t(:strip_all)
        end

        def self.outdoor_active_to_image
          t(:stringify_keys)
          .>> t(:add_field, 'content_url', ->(s) { "http://img.oastatic.com/img/#{s['id']}/.jpg" })
          .>> t(:add_field, 'thumbnail_url', ->(s) { "http://img.oastatic.com/img/400/400/fit/#{s['id']}/.jpg" })
          .>> t(:map_value, 'license', ->(s) { s.to_s if s.present? })
          .>> t(:rename_keys, { 'id' => 'external_key', 'title' => 'headline' })
          .>> t(:reject_keys, ['meta', 'primary', 'gallery'])
          .>> t(:strip_all)
        end

        def self.tour(geometry)
          return nil if geometry.blank?
          factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          factory.line_string(
            geometry&.split(' ')
              &.map { |p| p.split(',').map(&:to_f) }
              &.map { |p| factory.point(*p) }
          )
        end
      end
    end
  end
end

# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.outdoor_active_to_poi
          t(:stringify_keys)
          .>> t(
            :rename_keys,
            {
              'id' => 'external_key',
              'title' => 'name',
              'shortText' => 'description',
              'longText' => 'text',
              'altitude' => 'elevation',
              'countryCode' => 'address_country',
              'fax' => 'fax_number',
              'phone' => 'telephone',
              'homepage' => 'url',
              'businessHours' => 'hours_available',
              'fee' => 'price',
              'gettingThere' => 'directions'
            }
          )
          .>> t(:map_value, 'elevation', ->(s) { s.to_f })
          .>> t(:add_field, 'latitude', ->(s) { s['geometry'].try(:split, /[, ]/, 3).try(:[], 1).try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s['geometry'].try(:split, /[, ]/, 3).try(:[], 0).try(:to_f) })
          .>> t(:location)
          .>> t(:add_field, 'address_locality', ->(s) { s['address'].try(:[], 'town') })
          .>> t(:add_field, 'street_address', lambda(s) {
            [s['address'].try(:[], 'street').try(:strip), s['address'].try(:[], 'housenumber').try(:strip)].join(' ') if s['address'].try(:[], 'street').try(:strip).present?
          })
          .>> t(:add_field, 'postal_code', ->(s) { s['address'].try(:[], 'zipcode') })
          .>> t(:add_field, 'author', ->(s) { s['meta'].try(:[], 'author') })
          .>> t(:reject_keys, ['address', 'category', 'primaryImage', 'images', 'regions', 'meta'])
          .>> t(:strip_all)
        end

        def self.outdoor_active_to_place
          t(:stringify_keys)
          .>> t(:rename_keys, {
                  'id' => 'external_key',
                  'title' => 'name',
                  'shortText' => 'description',
                  'longText' => 'text',
                  'altitude' => 'elevation',
                  'countryCode' => 'address_country',
                  'fax' => 'fax_number',
                  'phone' => 'telephone',
                  'homepage' => 'url',
                  'businessHours' => 'hours_available',
                  'gettingThere' => 'directions'
                })
          .>> t(:map_value, 'elevation', ->(s) { s.to_f })
          .>> t(:add_field, 'latitude', ->(s) { s['geometry'].try(:split, /[, ]/, 3).try(:[], 1).try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s['geometry'].try(:split, /[, ]/, 3).try(:[], 0).try(:to_f) })
          .>> t(:location)
          .>> t(:add_field, 'address_locality', ->(s) { s['address'].try(:[], 'town') })
          .>> t(:add_field, 'street_address', lambda(s) {
            [s['address'].try(:[], 'street').try(:strip), s['address'].try(:[], 'housenumber').try(:strip)].join(' ') if s['address'].try(:[], 'street').try(:strip).present?
          })
          .>> t(:add_field, 'postal_code', ->(s) { s['address'].try(:[], 'zipcode') })
          .>> t(:add_field, 'author', ->(s) { s['meta'].try(:[], 'author') })
          .>> t(:strip_all)
        end

        def self.outdoor_active_to_tour
          t(:stringify_keys)
          .>> t(:add_field, 'latitude', ->(s) { s['startingPoint'].try(:[], 'lon').try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s['startingPoint'].try(:[], 'lat').try(:to_f) })
          .>> t(:add_field, 'start_location', lambda(s) {
            RGeo::Geographic.spherical_factory(srid: 4326).point(s['latitude'], s['longitude']) if s['longitude'] && s['latitude']
          })
          .>> t(:add_field, 'tour', lambda(s) {
            factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
            factory.line_string(
              s['geometry'].try(:split, ' ')
                .try(:map) { |p| p.split(',').map(&:to_f) }
                .try(:map) { |p| factory.point(*p) }
            )
          })
          .>> t(:unwrap, 'elevation', ['ascent', 'descent', 'minAltitude', 'maxAltitude'])
          .>> t(:unwrap, 'time', ['min'])
          .>> t(:unwrap, 'rating', ['condition', 'difficulty', 'experience', 'landscape'])
          .>> t(:add_field, 'author', ->(s) { s['meta'].try(:[], 'author') })
          .>> t(:rename_keys, {
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
                })
          .>> t(:map_value, 'elevation', ->(s) { s.to_f })
          .>> t(:map_value, 'length', ->(s) { s.to_f })
          .>> t(:map_value, 'duration', ->(s) { s.to_i })
          .>> t(:map_value, 'condition_rating', ->(s) { s.to_i })
          .>> t(:map_value, 'difficulty_rating', ->(s) { s.to_i })
          .>> t(:map_value, 'experience_rating', ->(s) { s.to_i })
          .>> t(:map_value, 'landscape_rating', ->(s) { s.to_i })
          .>> t(:strip_all)
        end

        def self.outdoor_active_to_image
          t(:stringify_keys)
          .>> t(:add_field, 'content_url', ->(s) { "http://img.oastatic.com/img/#{s['id']}/.jpg" })
          .>> t(:add_field, 'thumbnail_url', ->(s) { "http://img.oastatic.com/img/400/400/fit/#{s['id']}/.jpg" })
          .>> t(:map_value, 'license', ->(s) { s.to_s if s.present? })
          .>> t(:rename_keys, {
                  'id' => 'external_key',
                  'title' => 'headline'
                })
          .>> t(:reject_keys, ['meta', 'primary', 'gallery'])
          .>> t(:strip_all)
        end
      end
    end
  end
end

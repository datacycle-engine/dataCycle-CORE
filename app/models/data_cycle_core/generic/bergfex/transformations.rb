# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.bergfex_to_see
          t(:stringify_keys)
          .>> t(:reject_keys, ['region'])
          .>> t(:rename_keys, {
                  'id' => 'external_key',
                  'name' => 'name_old',
                  'area' => 'area_old',
                  'depth' => 'depth_old',
                  'temperature' => 'temperature_old'
                })
          .>> t(:add_field, 'name', ->(s) { s.dig('name_old', 'text') })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('lat', 'text')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('lng', 'text')&.to_f })
          .>> t(:add_field, 'location', ->(s) { RGeo::Geographic.spherical_factory(srid: 4326).point(s['longitude'], s['latitude']) if s['longitude'] && s['latitude'] })
          .>> t(:add_field, 'temperature', ->(s) { s.dig('temperature_old', 'text')&.to_f })
          .>> t(:add_field, 'temp_at', ->(s) { s.dig('temperature_old', 't') })
          .>> t(:add_field, 'quality', ->(s) { s.dig('quality', 'text') })
          .>> t(:nest, 'water_temp', ['temperature', 'temp_at', 'quality'])
          .>> t(:add_field, 'area', ->(s) { s.dig('area_old', 'text')&.to_f })
          .>> t(:add_field, 'depth', ->(s) { s.dig('depth_old', 'text')&.to_f })
          .>> t(:reject_keys, ['name_old', 'lat', 'lng', 'temperature_old', 'area_old', 'depth_old'])
          .>> t(:add_field, 'valid_from', ->(s) { s.dig('season', 'start', 'text') })
          .>> t(:add_field, 'valid_through', ->(s) { s.dig('season', 'end', 'text') })
          .>> t(:reject_keys, ['season'])
          .>> t(:add_field, 'opens', ->(s) { s.dig('openinghours', 'from', 'text') })
          .>> t(:add_field, 'closes', ->(s) { s.dig('openinghours', 'to', 'text') })
          .>> t(:nest, 'season', ['valid_from', 'valid_through'])
          .>> t(:nest, 'opening_data', ['season', 'opens', 'closes'])
          .>> t(:add_field, 'opening_hours_specification', ->(s) { [s.dig('opening_data')] })
          .>> t(:add_field, 'url', ->(s) { s.dig('link', 'text') })
          .>> t(:reject_keys, ['season', 'link'])
          .>> t(:strip_all)
        end
      end
    end
  end
end

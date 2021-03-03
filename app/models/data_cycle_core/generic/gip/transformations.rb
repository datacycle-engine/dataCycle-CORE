# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gip
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_section
          t(:stringify_keys)
          .>> t(:rename_keys, { 'id' => 'external_key', 'caption' => 'name' })
          .>> t(:add_field, 'section', ->(s) { parse_section(s.dig('geometry')) })
          .>> t(:reject_keys, ['bbox', 'geometry', 'properties'])
          .>> t(:strip_all)
        end

        def self.parse_section(geometry)
          return nil if geometry.blank? || geometry.dig('coordinates').blank? || geometry.dig('SRID').blank?
          return if geometry.dig('SRID') != 31_256 # Österreich Ost
          factory_source = RGeo::Cartesian.factory(srid: 31_256, proj4: '+proj=tmerc +lat_0=0 +lon_0=16.33333333333333 +k=1 +x_0=0 +y_0=-5000000 +ellps=bessel +towgs84=577.326,90.129,463.919,5.137,1.474,5.297,2.4232 +units=m +no_defs ')
          longlat = RGeo::Cartesian.factory(srid: 4326, proj4: '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')

          coordinates = geometry['coordinates']
          source_coordinates =
            if geometry['type'] == 'LineString'
              factory_source.line_string(coordinates.map { |i| factory_source.point(*i) })
            elsif geometry['type'] == 'MultiLineString'
              factory_source.multi_line_string(coordinates.map { |j| factory_source.line_string(j.map { |i| factory_source.point(*i) }) })
            else
              raise EndpointError "unknown geometry type found in Gip importer: #{geometry['type']}"
            end

          RGeo::Feature.cast(source_coordinates, factory: longlat, project: true)
        end
      end
    end
  end
end

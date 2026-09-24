# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      module SharedComponents
        # Geometry building blocks (GeoCoordinates / GeoShape) plus the shared
        # GeoJSON geometry shape. Extended into SharedComponents so its methods
        # are available as SharedComponents.* module methods (mirrors Localizable).
        module Geo
          # Point geometry: { @id, @type: GeoCoordinates, longitude, latitude, elevation }.
          def geo_coordinates
            {
              'type' => 'object',
              'title' => 'GeoCoordinates',
              'properties' => {
                '@id' => id_property,
                '@type' => { 'type' => 'string', 'const' => 'GeoCoordinates' },
                'longitude' => { 'type' => 'number' },
                'latitude' => { 'type' => 'number' },
                'elevation' => { 'type' => 'number' }
              },
              'required' => ['@type']
            }
          end

          # Area geometry. dataCycle emits { @id, @type: GeoShape, polygon|line }
          # where the value is a GeoJSON geometry (geoshape_as_json -> geom.as_json).
          def geo_shape
            {
              'type' => 'object',
              'title' => 'GeoShape',
              'properties' => {
                '@id' => id_property,
                '@type' => { 'type' => 'string', 'const' => 'GeoShape' },
                'polygon' => geo_json_geometry,
                'line' => geo_json_geometry
              },
              'required' => ['@type']
            }
          end

          # A GeoJSON geometry object (RGeo #as_json output).
          def geo_json_geometry
            {
              'type' => 'object',
              'properties' => {
                'type' => { 'type' => 'string', 'description' => t('schemas.geo_json_type') },
                'coordinates' => { 'type' => 'array', 'items' => {}, 'description' => t('schemas.geo_json_coordinates') }
              }
            }
          end
        end
      end
    end
  end
end

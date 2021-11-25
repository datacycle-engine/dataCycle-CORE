# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Geojson
        extend ActiveSupport::Concern
        def geojson_feature
          # return if geojson_geometry.nil?
          factory = RGeo::GeoJSON::EntityFactory.instance
          factory.feature(geojson_geometry, id, geojson_properties)
        end

        def as_geojson
          # TODO: caching
          RGeo::GeoJSON.encode(geojson_feature)
        end

        def to_geojson
          as_geojson.to_json
        end

        def geojson_geometry
          # TODO: line or point or GeometryCollection? 
          # coordinate precision -> not implemented in rgeo
          line
        end

        def geojson_properties
          { name: name }
        end

        class_methods do
          def as_geojson
            factory = RGeo::GeoJSON::EntityFactory.instance
            feature_collection = factory.feature_collection(all.includes(:translations).map(&:geojson_feature))
            RGeo::GeoJSON.encode(feature_collection)
          end

          def to_geojson
            as_geojson.to_json
          end
        end
      end
    end
  end
end

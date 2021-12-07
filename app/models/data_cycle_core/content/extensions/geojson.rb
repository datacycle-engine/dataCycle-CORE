# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Geojson
        extend ActiveSupport::Concern
        def geojson_feature
          factory = RGeo::GeoJSON::EntityFactory.instance
          Rails.cache.fetch(geojson_cache_key, expires_in: 1.year + Random.rand(7.days)) do
            factory.feature(geojson_geometry, id, geojson_properties)
          end
        end

        def as_geojson
          RGeo::GeoJSON.encode(geojson_feature)
        end

        def to_geojson
          as_geojson.to_json
        end

        def geojson_geometry
          # coordinate precision -> not implemented in rgeo
          if line.present? && location.present?
            # binding.pry
            # TODO: 3D or not?
            # factory = RGeo::Geographic.spherical_factory(srid: 4326, proj4: '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs', has_z_coordinate: true)
            factory = RGeo::Geographic.spherical_factory
            return factory.collection([line, location])
          end
          return line unless line.nil?
          return location unless location.nil?
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

        private

        def geojson_cache_key
          "#{self.class.name.underscore}/#{id}_#{I18n.locale}_#{updated_at.to_i}_#{template_updated_at.to_i}"
        end
      end
    end
  end
end

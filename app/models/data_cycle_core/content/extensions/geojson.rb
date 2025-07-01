# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Geojson
        extend ActiveSupport::Concern

        def as_geojson
          factory = RGeo::GeoJSON::EntityFactory.instance
          Rails.cache.fetch(geojson_cache_key, expires_in: 1.year + Random.rand(7.days)) do
            factory.feature(geojson_geometry, id, geojson_properties).as_geojson
          end
        end

        def to_geojson(simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [])
          DataCycleCore::Geo::GeojsonRenderer.new(contents: self.class.where(id:).limit(1), simplify_factor:, include_parameters:, fields_parameters:, classification_trees_parameters:, single_item: true).render
        end

        def geojson_geometry(content = self)
          line = content.try(:line)
          location = content.try(:location)

          if line.present? && location.present?
            longlat_projection = RGeo::CoordSys::Proj4.new('EPSG:4326')
            factory = RGeo::Geographic.spherical_factory(srid: 4326, proj4: longlat_projection, has_z_coordinate: true)
            return factory.collection([line, location])
          end
          return line unless line.nil?
          location
        end

        def geojson_properties
          { id:, name: title }
        end

        class_methods do
          def as_geojson
            factory = RGeo::GeoJSON::EntityFactory.instance
            feature_collection = factory.feature_collection(all.map { |c| RGeo::GeoJSON.decode(c.as_geojson) }.flatten)
            RGeo::GeoJSON.encode(feature_collection)
          end

          def to_geojson(simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false)
            DataCycleCore::Geo::GeojsonRenderer.new(contents: all, simplify_factor:, include_parameters:, fields_parameters:, classification_trees_parameters:, single_item:).render
          end
        end

        private

        def geojson_cache_key
          "#{self.class.name.underscore}/geojson/#{id}_#{I18n.locale}_#{updated_at.to_i}_#{cache_valid_since.to_i}"
        end
      end
    end
  end
end

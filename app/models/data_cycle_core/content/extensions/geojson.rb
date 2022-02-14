# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Geojson
        extend ActiveSupport::Concern

        SIMPLIFY_FACTOR = 0.00001
        GEOMETRY_PRECISION = 0.00001
        SELECT_SQL = <<-SQL.squish
          things.id AS id,
          ST_Simplify (ST_ReducePrecision (ST_Force2D (
                CASE WHEN things.line IS NULL THEN
                  things.location
                ELSE
                  things.line
                END), :geometry_precision), :simplify_factor, TRUE) AS geometry
        SQL

        ADDITIONAL_GEOJSON_PROPERTIES = {
          name: 'thing_translations.name'
        }.freeze

        TO_GEOJSON_QUERY_SQL = <<-SQL.squish
          SELECT
            json_build_object('type', 'FeatureCollection', 'crs', json_build_object('type', 'name', 'properties',
              json_build_object('name', 'urn:ogc:def:crs:EPSG::4326')), 'features', json_agg(json_build_object('type', 'Feature',
              'id', t.id, 'geometry', ST_AsGeoJSON (t.geometry)::json, 'properties', json_build_object(#{ADDITIONAL_GEOJSON_PROPERTIES.keys.map { |k| "'#{k}', t.#{k}" }.join(', ')}))))
          FROM (:from_query) AS t
        SQL

        TO_GEOJSON_DETAIL_QUERY_SQL = <<-SQL.squish
          SELECT
            json_build_object('type', 'Feature', 'crs', json_build_object('type', 'name', 'properties',
              json_build_object('name', 'urn:ogc:def:crs:EPSG::4326')), 'id', t.id, 'geometry', ST_AsGeoJSON (t.geometry)::json, 'properties',
              json_build_object(#{ADDITIONAL_GEOJSON_PROPERTIES.keys.map { |k| "'#{k}', t.#{k}" }.join(', ')}))
          FROM (:from_query) AS t
        SQL

        def geojson_feature
          factory = RGeo::GeoJSON::EntityFactory.instance
          Rails.cache.fetch(geojson_cache_key, expires_in: 1.year + Random.rand(7.days)) do
            factory.feature(geojson_geometry, id, geojson_properties)
          end
        end

        def as_geojson
          RGeo::GeoJSON.encode(geojson_feature)
        end

        def to_geojson(simplify_factor = SIMPLIFY_FACTOR)
          self.class.where(id: id).limit(1).to_geojson(simplify_factor, TO_GEOJSON_DETAIL_QUERY_SQL)
        end

        def geojson_geometry(content = self)
          # TODO: coordinate precision -> not implemented in rgeo
          if content.line.present? && content.location.present?
            factory = RGeo::Geographic.spherical_factory(srid: 4326, proj4: '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs', has_z_coordinate: true)
            return factory.collection([content.line, content.location])
          end
          return content.line unless content.line.nil?
          return content.location unless content.location.nil?
        end

        def geojson_properties
          { name: title }
        end

        class_methods do
          def geojson_default_scope(simplify_factor = SIMPLIFY_FACTOR)
            all.except(:order)
              .left_outer_joins(:translations)
              .where(thing_translations: { locale: I18n.locale })
              .select(
                Array.wrap(ADDITIONAL_GEOJSON_PROPERTIES.map { |k, v| "#{v} AS #{k}" }).prepend(
                  ActiveRecord::Base.send(:sanitize_sql_array, [
                                            SELECT_SQL,
                                            geometry_precision: GEOMETRY_PRECISION,
                                            simplify_factor: simplify_factor
                                          ])
                ).join(', ')
              )
          end

          def as_geojson
            factory = RGeo::GeoJSON::EntityFactory.instance
            feature_collection = factory.feature_collection(all.map(&:geojson_feature).flatten)
            RGeo::GeoJSON.encode(feature_collection)
          end

          def to_geojson(simplify_factor = SIMPLIFY_FACTOR, query = TO_GEOJSON_QUERY_SQL)
            things_query = all.geojson_default_scope(simplify_factor)

            ActiveRecord::Base.connection.execute(ActiveRecord::Base.send(:sanitize_sql_array, [query.gsub(':from_query', things_query.to_sql)])).first&.values&.first
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

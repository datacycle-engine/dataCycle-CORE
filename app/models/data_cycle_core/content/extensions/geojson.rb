# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Geojson
        extend ActiveSupport::Concern

        SIMPLIFY_FACTOR = 0.00001
        GEOMETRY_PRECISION = 5
        CRS_SQL = ", 'crs', json_build_object('type', 'name', 'properties', json_build_object('name', 'urn:ogc:def:crs:EPSG::4326'))"

        ADDITIONAL_GEOJSON_PROPERTIES = {
          name: 'thing_translations.name'
        }.freeze

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
          self.class.where(id: id).limit(1).to_geojson(simplify_factor: simplify_factor, geojson_query: self.class.geojson_sql(self.class.geojson_detail_select_sql(true)))
        end

        def geojson_geometry(content = self)
          # TODO: coordinate precision -> not implemented in rgeo
          if content.line.present? && content.location.present?
            longlat_projection = RGeo::CoordSys::Proj4.new('EPSG:4326')
            factory = RGeo::Geographic.spherical_factory(srid: 4326, proj4: longlat_projection, has_z_coordinate: true)
            return factory.collection([content.line, content.location])
          end
          return content.line unless content.line.nil?
          return content.location unless content.location.nil?
        end

        def geojson_properties
          { name: title }
        end

        class_methods do
          def geojson_default_scope(simplify_factor: SIMPLIFY_FACTOR)
            all.except(:order)
              .left_outer_joins(:translations)
              .where(thing_translations: { locale: I18n.locale })
              .select(
                Array.wrap(ADDITIONAL_GEOJSON_PROPERTIES.map { |k, v| "#{v} AS #{k}" }).prepend(
                  ActiveRecord::Base.send(:sanitize_sql_array, [
                                            geojson_content_select_sql,
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

          def to_geojson(include_without_geometry: true, simplify_factor: SIMPLIFY_FACTOR, geojson_query: geojson_sql(geojson_select_sql))
            geojson_result(
              all.geojson_default_scope(simplify_factor: simplify_factor),
              geojson_query,
              include_without_geometry
            )
          end

          def geojson_result(things_query, geojson_query, include_without_geometry)
            geojson_query += ' WHERE t.geometry IS NOT NULL' unless include_without_geometry

            ActiveRecord::Base.connection.execute(
              ActiveRecord::Base.send(:sanitize_sql_array, [
                                        geojson_query.gsub(':from_query', things_query.to_sql)
                                      ])
            ).first&.values&.first
          end

          def geojson_geometry_sql
            <<-SQL.squish
              CASE WHEN things.line IS NULL THEN
                things.location
              ELSE
                things.line
              END
            SQL
          end

          def geojson_content_select_sql
            <<-SQL.squish
              things.id AS id,
              ST_Simplify (ST_Force2D (#{geojson_geometry_sql}), :simplify_factor, TRUE) AS geometry
            SQL
          end

          def geojson_sql(select_sql)
            <<-SQL.squish
              SELECT #{select_sql}
              FROM (:from_query) AS t
            SQL
          end

          def geojson_detail_select_sql(include_crs = false)
            <<-SQL.squish
              json_build_object('type', 'Feature'#{CRS_SQL if include_crs}, 'id', t.id, 'geometry', ST_AsGeoJSON (t.geometry, #{GEOMETRY_PRECISION})::json, 'properties',
                json_build_object(#{ADDITIONAL_GEOJSON_PROPERTIES.keys.map { |k| "'#{k}', t.#{k}" }.join(', ')}))
            SQL
          end

          def geojson_select_sql
            <<-SQL.squish
              json_build_object('type', 'FeatureCollection'#{CRS_SQL}, 'features', json_agg(#{geojson_detail_select_sql}))
            SQL
          end
        end

        private

        def geojson_cache_key
          "#{self.class.name.underscore}/#{id}_#{I18n.locale}_#{updated_at.to_i}_#{cache_valid_since.to_i}"
        end
      end
    end
  end
end

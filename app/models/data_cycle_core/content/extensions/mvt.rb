# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Mvt
        extend ActiveSupport::Concern

        SIMPLIFY_FACTOR = 0.00001
        GEOMETRY_PRECISION = 5
        CRS_SQL = ", 'crs', json_build_object('type', 'name', 'properties', json_build_object('name', 'urn:ogc:def:crs:EPSG::4326'))"

        ADDITIONAL_GEOJSON_PROPERTIES = {
          name: 'thing_translations.name'
        }.freeze

        # def geojson_feature
        #   factory = RGeo::GeoJSON::EntityFactory.instance
        #   Rails.cache.fetch(geojson_cache_key, expires_in: 1.year + Random.rand(7.days)) do
        #     factory.feature(geojson_geometry, id, geojson_properties)
        #   end
        # end

        # def as_geojson
        #   RGeo::GeoJSON.encode(geojson_feature)
        # end

        # def to_mvt(simplify_factor = SIMPLIFY_FACTOR)
        #   binding.pry
        #   self.class.where(id: id).limit(1).to_geojson(simplify_factor: simplify_factor, geojson_query: self.class.geojson_sql(self.class.geojson_detail_select_sql(true)))
        # end

        # def geojson_geometry(content = self)
        #   # TODO: coordinate precision -> not implemented in rgeo
        #   if content.line.present? && content.location.present?
        #     longlat_projection = RGeo::CoordSys::Proj4.new('EPSG:4326')
        #     factory = RGeo::Geographic.spherical_factory(srid: 4326, proj4: longlat_projection, has_z_coordinate: true)
        #     return factory.collection([content.line, content.location])
        #   end
        #   return content.line unless content.line.nil?
        #   return content.location unless content.location.nil?
        # end

        # def geojson_properties
        #   { id: id, name: title }
        # end

        class_methods do
          def mvt_default_scope(simplify_factor: SIMPLIFY_FACTOR)
            all.except(:order)
              .left_outer_joins(:translations)
              .where(thing_translations: { locale: I18n.locale })
              .select(
                Array.wrap(ADDITIONAL_GEOJSON_PROPERTIES.map { |k, v| "#{v} AS #{k}" }).prepend(
                  ActiveRecord::Base.send(:sanitize_sql_array, [
                                            mvt_content_select_sql,
                                            simplify_factor: simplify_factor
                                          ])
                ).join(', ')
              )
          end

          # def as_geojson
          #   factory = RGeo::GeoJSON::EntityFactory.instance
          #   feature_collection = factory.feature_collection(all.map(&:geojson_feature).flatten)
          #   RGeo::GeoJSON.encode(feature_collection)
          # end

          # def to_mvt(x, y, z, include_parameters: [], fields_parameters: [], classification_trees_parameters: [])
          #   DataCycleCore::Geo::MvtRenderer.new(x, y, z, contents: all, simplify_factor: simplify_factor, include_parameters: include_parameters, fields_parameters: fields_parameters, classification_trees_parameters: classification_trees_parameters, single_item: single_item).render
          # end

          def to_mvt(x, y, z, simplify_factor: SIMPLIFY_FACTOR) # rubocop:disable Lint/unusedMethodArgument
            # def to_mvt(simplify_factor: SIMPLIFY_FACTOR, geojson_query: mvt_sql(mvt_select_sql))
            # binding.pry
            mvt_result(
              all.mvt_default_scope(simplify_factor: 1 / (2**z.to_f)),
              mvt_sql(x, y, z)
              # geojson_query,

            )
          end

          def mvt_result(things_query, geojson_query)
            ActiveRecord::Base.connection.unescape_bytea(
              ActiveRecord::Base.connection.execute(
                Arel.sql(geojson_query.gsub(':from_query', things_query.to_sql))
              ).first&.values&.first
            )
          end

          def mvt_geometry_sql
            <<-SQL.squish
              CASE WHEN things.line IS NULL THEN
                things.location
              ELSE
                things.line
              END
            SQL
          end

          def mvt_content_select_sql
            <<-SQL.squish
              things.id AS id,
              ST_Simplify (ST_Force2D (#{mvt_geometry_sql}), :simplify_factor, TRUE) AS geometry
            SQL
          end

          def mvt_sql(x, y, z)
            # Resources:
            # https://github.com/CrunchyData/pg_tileserv
            # https://github.com/pramsey/minimal-mvt/
            # https://postgis.net/docs/ST_AsMVT.html
            # https://www.crunchydata.com/blog/crunchy-spatial-tile-serving-with-postgresql-functions
            # https://www.crunchydata.com/blog/waiting-for-postgis-3-st_tileenvelopezxy
            # def mvt_sql(select_sql)
            #   WITH
            #   bounds AS (
            #   SELECT ST_TileEnvelope(z, x, y) AS geom
            # ),
            #   -- Convert raw geometry into MVT geometry
            #   -- Pull just the name in addition to the geometry
            #   -- Apply the name_prefix parameter to the WHERE clause
            #   mvtgeom AS (
            #       SELECT ST_AsMVTGeom(ST_Transform(t.geom, 3857), bounds.geom) AS geom,
            #         t.name
            #       FROM ne_50m_admin_0_countries t, bounds
            #       WHERE ST_Intersects(t.geom, ST_Transform(bounds.geom, 4326))
            #       AND upper(t.name) LIKE (upper(name_prefix) || '%')
            #     )
            #     -- Serialize the result set into an MVT object
            #     SELECT ST_AsMVT(mvtgeom, 'public.countries_name') FROM mvtgeom;
            <<-SQL.squish
              WITH
              bounds AS (
                SELECT ST_TileEnvelope(#{z}, #{x}, #{y}) AS geom
              ),
              mvtgeom AS (
                SELECT ST_AsMVTGeom(ST_Transform(t.geometry, 3857), bounds.geom) AS geom,
                  t.id, t.name
                FROM (:from_query) as t, bounds
                WHERE ST_Intersects(t.geometry, ST_Transform(bounds.geom, 4326))
              )
              SELECT ST_AsMVT(mvtgeom, 'dataCycle') FROM mvtgeom;
            SQL
          end

          # def geojson_detail_select_sql(include_crs = false)
          #   <<-SQL.squish
          #     json_build_object('type', 'Feature'#{CRS_SQL if include_crs}, 'id', t.id, 'geometry', ST_AsGeoJSON (t.geometry, #{GEOMETRY_PRECISION})::json, 'properties',
          #       json_build_object('id', t.id, #{ADDITIONAL_GEOJSON_PROPERTIES.keys.map { |k| "'#{k}', t.#{k}" }.join(', ')}))
          #   SQL
          # end

          # def mvt_select_sql
          #   <<-SQL.squish
          #     -- json_build_object('type', 'FeatureCollection'#{CRS_SQL}, 'features', json_agg(#{geojson_detail_select_sql}))
          #     ST_AsMVT(mvtgeom, 'dataCycle')
          #   SQL
          # end
        end

        private

        def geojson_cache_key
          "#{self.class.name.underscore}/#{id}_#{I18n.locale}_#{updated_at.to_i}_#{cache_valid_since.to_i}"
        end
      end
    end
  end
end

# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Geojson
        extend ActiveSupport::Concern

        SIMPLIFY_FACTOR = 0.00001
        GEOMETRY_PRECISION = 5
        CRS_SQL = ", 'crs', json_build_object('type', 'name', 'properties', json_build_object('name', 'urn:ogc:def:crs:EPSG::4326'))"

        def geojson_feature
          factory = RGeo::GeoJSON::EntityFactory.instance
          Rails.cache.fetch(geojson_cache_key, expires_in: 1.year + Random.rand(7.days)) do
            factory.feature(geojson_geometry, id, geojson_properties)
          end
        end

        def as_geojson
          RGeo::GeoJSON.encode(geojson_feature)
        end

        def to_geojson(simplify_factor: SIMPLIFY_FACTOR, include_parameters: [], fields_parameters: [], classification_trees_parameters: [])
          self.class.where(id: id).limit(1).to_geojson(simplify_factor: simplify_factor, include_parameters: include_parameters, fields_parameters: fields_parameters, classification_trees_parameters: classification_trees_parameters, single_item: true)
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
          { id: id, name: title }
        end

        class_methods do
          def geojson_default_scope
            query = all.except(:order).select(geojson_content_select_sql)

            joins = geojson_include_config.pluck(:joins)
            joins.uniq!
            joins.compact!

            joins.each { |join| query = query.joins(join.squish) }

            query
          end

          def as_geojson
            factory = RGeo::GeoJSON::EntityFactory.instance
            feature_collection = factory.feature_collection(all.map(&:geojson_feature).flatten)
            RGeo::GeoJSON.encode(feature_collection)
          end

          def to_geojson(include_without_geometry: true, simplify_factor: SIMPLIFY_FACTOR, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false)
            @include_without_geometry = include_without_geometry
            @simplify_factor = simplify_factor
            @include_parameters = include_parameters
            @fields_parameters = fields_parameters
            @classification_trees_parameters = classification_trees_parameters
            @single_item = single_item

            geojson_result(
              all.geojson_default_scope,
              geojson_sql(@single_item ? geojson_detail_select_sql : geojson_select_sql)
            )
          end

          def geojson_result(things_query, geojson_query)
            geojson_query += ' WHERE t.geometry IS NOT NULL' unless @include_without_geometry

            ActiveRecord::Base.connection.execute(
              Arel.sql(geojson_query.gsub(':from_query', things_query.to_sql))
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
            [
              'things.id AS id',
              "ST_Simplify (ST_Force2D (#{geojson_geometry_sql}), #{@simplify_factor || SIMPLIFY_FACTOR}, TRUE) AS geometry"
            ]
              .concat(geojson_include_config.map { |c| "#{c[:select]} AS #{c[:identifier]}" })
              .join(', ').squish
          end

          def geojson_sql(select_sql)
            <<-SQL.squish
              SELECT #{select_sql}
              FROM (:from_query) AS t
            SQL
          end

          def geojson_detail_select_sql
            <<-SQL.squish
              json_build_object('type', 'Feature', 'id', t.id, 'geometry', ST_AsGeoJSON (t.geometry, #{GEOMETRY_PRECISION})::json, 'properties',
                json_build_object(#{geojson_include_config.pluck(:identifier).prepend('id').map { |p| "'#{p}', t.#{p}" }.join(', ')}))
            SQL
          end

          def geojson_select_sql
            <<-SQL.squish
              json_build_object('type', 'FeatureCollection'#{CRS_SQL}, 'features', json_agg(#{geojson_detail_select_sql}))
            SQL
          end

          def geojson_include_config
            config = []

            if @fields_parameters.blank? || @fields_parameters&.any? { |p| p.first == 'name' }
              config << {
                identifier: 'name',
                select: 'thing_translations.name',
                joins: "LEFT OUTER JOIN thing_translations ON thing_translations.thing_id = things.id
                        AND thing_translations.locale = '#{I18n.locale}'"
              }
            end

            if @include_parameters&.any? { |p| p.first == 'dc:classification' } || @fields_parameters&.any? { |p| p.first == 'dc:classification' }
              fields_parameters = @fields_parameters.select { |p| p.first == 'dc:classification' }.map { |p| p.except('dc:classification') }.compact_blank.flatten
              json_object = []
              json_object.push("'@id', classification_aliases.id") if fields_parameters.blank? || fields_parameters.include?('@id')
              json_object.push("'dc:path', classification_alias_paths.full_path_names") if fields_parameters.blank? || fields_parameters.include?('dc:path')

              config << {
                identifier: '"dc:classification"',
                select: 'tmp1."dc:classification"',
                joins: "LEFT OUTER JOIN (
                  SELECT
                    classification_contents.content_data_id,
                    json_agg(
                      json_build_object(#{json_object.join(', ')})
                    ) AS \"dc:classification\"
                  FROM
                    classification_aliases
                    INNER JOIN classification_groups ON classification_groups.deleted_at IS NULL
                    AND classification_groups.classification_alias_id = classification_aliases.id
                    INNER JOIN classifications ON classifications.deleted_at IS NULL
                    AND classifications.id = classification_groups.classification_id
                    INNER JOIN classification_trees ON classification_trees.deleted_at IS NULL
                    AND classification_trees.classification_alias_id = classification_aliases.id
                    INNER JOIN classification_tree_labels ON classification_tree_labels.deleted_at IS NULL
                    AND classification_tree_labels.id = classification_trees.classification_tree_label_id
                    INNER JOIN classification_contents ON classification_contents.classification_id = classifications.id
                    #{'INNER JOIN classification_alias_paths ON classification_alias_paths.id = classification_aliases.id' if fields_parameters.blank? || fields_parameters.include?('dc:path')}
                  WHERE
                    classification_aliases.deleted_at IS NULL
                    AND 'api' = ANY(classification_tree_labels.visibility)
                    #{"AND classification_trees.classification_tree_label_id IN (\'#{@classification_trees_parameters.join('\',\'')}\')" if @classification_trees_parameters.present?}
                  GROUP BY
                    classification_contents.content_data_id
                ) AS tmp1 ON tmp1.content_data_id = things.id"
              }
            end

            config
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

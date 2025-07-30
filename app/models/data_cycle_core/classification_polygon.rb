# frozen_string_literal: true

module DataCycleCore
  class ClassificationPolygon < ApplicationRecord
    belongs_to :classification_alias

    def self.to_bbox
      select_sql = <<-SQL.squish
        json_build_object(
          'xmin', st_xmin(ST_Extent(classification_polygons.geom_simple)),
          'ymin', st_ymin(ST_Extent(classification_polygons.geom_simple)),
          'xmax', st_xmax(ST_Extent(classification_polygons.geom_simple)),
          'ymax', st_ymax(ST_Extent(classification_polygons.geom_simple))
        )
      SQL
      query = reorder(nil).except(:limit, :offset).select(select_sql)

      connection.select_all(query).first&.values&.first
    end

    def self.to_mvt(x, y, z, layer_name)
      select_sql = <<-SQL.squish
        classification_polygons.classification_alias_id AS id,
        classification_polygons.geom_simple AS geometry,
        array_to_json(ARRAY ['skos:Concept']::VARCHAR []) AS "@type",
        classification_alias.internal_name AS name
      SQL

      outer_select_sql = <<-SQL.squish
        ST_AsMVTGeom(ST_Transform(t.geometry, 3857), ST_TileEnvelope(#{z}, #{x}, #{y})) AS geom,
        t.id AS "@id",
        t."@type" AS "@type",
        t.name AS name
      SQL

      query = unscoped.with(
        mvtgeom: unscoped
                  .select(outer_select_sql)
                  .from(
                    reselect(select_sql)
                    .joins(:classification_alias)
                    .where(sanitize_sql(["ST_Intersects(classification_polygons.geom_simple, ST_Transform(ST_TileEnvelope(#{z}, #{x}, #{y}), 4326))"]))
                    .arel.as('t')
                  )
      )
        .select("ST_AsMVT(mvtgeom, '#{layer_name.presence || 'dcConcepts'}')")
        .from('mvtgeom')

      connection.unescape_bytea(
        connection.select_all(query).first&.values&.first
      )
    end

    def self.combined_geojson
      select_sql = <<-SQL.squish
        ST_AsGeoJSON(ST_Force3D(ST_MakeValid(ST_Union(classification_polygons.geom))), 6) AS geom
      SQL

      connection.select_all(except(:order).select(select_sql)).first&.values&.first
    end

    def self.upsert_all_geoms(data)
      count = 0
      return count if data.blank?

      data.each_slice(1000) do |group|
        transaction(joinable: false, requires_new: true) do
          connection.exec_query('SET LOCAL statement_timeout = 0;')
          where(classification_alias_id: group.pluck(:classification_alias_id)).delete_all
          inserted = insert_all(group, returning: :id)
          count += inserted.count
        end
      end

      count
    end
  end
end

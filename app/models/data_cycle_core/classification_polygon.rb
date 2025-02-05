# frozen_string_literal: true

module DataCycleCore
  class ClassificationPolygon < ApplicationRecord
    belongs_to :classification_alias

    def self.to_bbox
      select_sql = <<-SQL.squish
        json_build_object(
          'xmin', st_xmin(ST_Extent(classification_polygons."geom")),
          'ymin', st_ymin(ST_Extent(classification_polygons."geom")),
          'xmax', st_xmax(ST_Extent(classification_polygons."geom")),
          'ymax', st_ymax(ST_Extent(classification_polygons."geom"))
        )
      SQL
      query = reorder(nil).except(:limit, :offset).select(select_sql).to_sql

      ActiveRecord::Base.connection.select_all(
        Arel.sql(query)
      ).first&.values&.first
    end

    def self.to_mvt(x, y, z, layer_name)
      select_sql = <<-SQL.squish
        classification_polygons.classification_alias_id AS id,
        ST_Simplify (geom, 0.00001, TRUE) AS geometry,
        array_to_json(ARRAY ['skos:Concept']::VARCHAR []) AS "@type",
        classification_alias.internal_name AS name
      SQL

      query = <<-SQL.squish
        WITH mvtgeom AS (
          SELECT ST_AsMVTGeom(
              ST_Transform(t.geometry, 3857),
              ST_TileEnvelope(#{z}, #{x}, #{y})
            ) AS geom,
            t.id AS "@id",
            t."@type" AS "@type",
            t.name AS name
          FROM (#{reselect(select_sql).joins(:classification_alias).where("ST_Intersects(geom, ST_Transform(ST_TileEnvelope(#{z}, #{x}, #{y}), 4326))").to_sql}) AS t
        )
        SELECT ST_AsMVT(mvtgeom, '#{layer_name.presence || 'dcConcepts'}')
        FROM mvtgeom;
      SQL

      ActiveRecord::Base.connection.unescape_bytea(
        ActiveRecord::Base.connection.select_all(
          Arel.sql(query)
        ).first&.values&.first
      )
    end

    def self.upsert_all_geoms(data)
      count = 0
      return count if data.blank?

      data.each_slice(1000) do |group|
        DataCycleCore::ClassificationPolygon.transaction(joinable: false, requires_new: true) do
          ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
          DataCycleCore::ClassificationPolygon.where(classification_alias_id: group.pluck(:classification_alias_id)).delete_all
          inserted = DataCycleCore::ClassificationPolygon.insert_all(group, returning: :id)
          count += inserted.count
        end
      end

      count
    end
  end
end

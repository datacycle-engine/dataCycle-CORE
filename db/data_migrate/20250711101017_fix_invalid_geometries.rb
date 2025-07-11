# frozen_string_literal: true

class FixInvalidGeometries < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      UPDATE geometries
      SET geom = fixed_geoms.geom
      FROM (
          SELECT geometries.id,
            ST_MakeValid(geometries.geom) AS geom
          FROM geometries
          WHERE NOT ST_IsValid(geometries.geom, 0)
        ) fixed_geoms
      WHERE geometries.id = fixed_geoms.id;

      UPDATE classification_polygons
      SET geom = fixed_geoms.geom
      FROM (
          SELECT classification_polygons.id,
            ST_MakeValid(classification_polygons.geom) AS geom
          FROM classification_polygons
          WHERE NOT ST_IsValid(classification_polygons.geom, 0)
        ) fixed_geoms
      WHERE classification_polygons.id = fixed_geoms.id;
    SQL

    validate_check_constraint :geometries, name: 'check_geom_validity'
    validate_check_constraint :classification_polygons, name: 'check_geom_validity'
  end

  def down
  end
end

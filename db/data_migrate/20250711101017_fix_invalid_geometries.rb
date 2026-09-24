# frozen_string_literal: true

# The polygon half was written against classification_polygons and ported by #41458 to whichever of the
# two tables holds the polygons in the schema it finds; the cut renamed it to concept_polygons and left
# the geometries table alone.
class FixInvalidGeometries < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    polygons = table_exists?(:classification_polygons) ? 'classification_polygons' : 'concept_polygons'

    execute <<~SQL.squish
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

      UPDATE #{polygons}
      SET geom = fixed_geoms.geom
      FROM (
          SELECT #{polygons}.id,
            ST_MakeValid(#{polygons}.geom) AS geom
          FROM #{polygons}
          WHERE NOT ST_IsValid(#{polygons}.geom, 0)
        ) fixed_geoms
      WHERE #{polygons}.id = fixed_geoms.id;
    SQL

    validate_check_constraint :geometries, name: 'check_geom_validity'
    validate_check_constraint polygons, name: 'check_geom_validity'
  end

  def down
  end
end

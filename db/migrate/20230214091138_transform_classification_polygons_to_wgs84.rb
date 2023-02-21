# frozen_string_literal: true

class TransformClassificationPolygonsToWgs84 < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      ALTER TABLE classification_polygons
      ADD COLUMN geom_4326 geometry(Geometry, 4326);

      UPDATE classification_polygons
      SET geom_4326 = st_transform(geom, 4326);

      DROP INDEX  classification_polygons_geom_idx;

      ALTER TABLE classification_polygons
      DROP COLUMN geom;

      ALTER TABLE classification_polygons
      RENAME COLUMN geom_4326 TO geom;

      CREATE INDEX classification_polygons_geom_idx ON classification_polygons USING gist(geom);
    SQL

    ActiveRecord::Base.connection.execute('VACUUM ANALYZE classification_polygons')
  end

  def down
  end
end

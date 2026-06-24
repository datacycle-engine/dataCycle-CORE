# frozen_string_literal: true

class FixGeometriesAndClassificationPolygons < ActiveRecord::Migration[7.1]
  def up
    # Fix Classification Polygons
    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;
      DROP TRIGGER IF EXISTS make_valid_classification_polygons_trigger ON public.classification_polygons;
      DROP INDEX IF EXISTS index_classification_polygons_on_geom_simple;
    SQL

    change_table :classification_polygons, bulk: true do |t|
      t.remove :geom_simple
      t.virtual :geom_simple, type: :geometry, srid: 4326, stored: true, as: 'ST_SimplifyPreserveTopology(st_force2d(geom), (0.00001)::double precision)'

      t.check_constraint "ST_GeometryType(geom) <> 'ST_GeometryCollection'", name: 'check_geom_type', validate: false
      t.check_constraint 'ST_IsValid(geom_simple, 0)', name: 'check_geom_simple_validity', validate: false
      t.check_constraint "ST_GeometryType(geom_simple) <> 'ST_GeometryCollection'", name: 'check_geom_simple_type', validate: false
    end

    add_index :classification_polygons, :geom_simple, using: :gist, name: 'index_classification_polygons_on_geom_simple'

    # Fix Geometries
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS make_valid_geometries_trigger ON public.geometries;
      DROP FUNCTION IF EXISTS public.make_valid_geometries();
      DROP INDEX IF EXISTS index_geometries_on_geom_simple;
      DROP INDEX IF EXISTS index_geometries_on_geom_simple_geography;
    SQL

    change_table :geometries, bulk: true do |t|
      t.remove :geom_simple
      t.virtual :geom_simple, type: :geometry, srid: 4326, stored: true, as: 'ST_SimplifyPreserveTopology(st_force2d(geom), (0.00001)::double precision)'

      t.check_constraint "ST_GeometryType(geom) <> 'ST_GeometryCollection'", name: 'check_geom_type', validate: false
      t.check_constraint 'ST_IsValid(geom_simple, 0)', name: 'check_geom_simple_validity', validate: false
      t.check_constraint "ST_GeometryType(geom_simple) <> 'ST_GeometryCollection'", name: 'check_geom_simple_type', validate: false
    end

    add_index :geometries, :geom_simple, using: :gist, name: 'index_geometries_on_geom_simple'
    add_index :geometries, 'geography(geom_simple)', using: :gist, name: 'index_geometries_on_geom_simple_geography'
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE classification_polygons DROP CONSTRAINT check_geom_type;
      ALTER TABLE classification_polygons DROP CONSTRAINT check_geom_simple_validity;
      ALTER TABLE classification_polygons DROP CONSTRAINT check_geom_simple_type;

      DROP INDEX IF EXISTS index_classification_polygons_on_geom_simple;
    SQL

    change_table :classification_polygons, bulk: true do |t|
      t.remove :geom_simple
      t.virtual :geom_simple, type: :geometry, srid: 4326, stored: true, as: 'ST_MakeValid(ST_GeomFromText(ST_AsText(ST_Simplify(ST_Force2d(geom), 0.00001, true), 5)))'
    end

    add_index :classification_polygons, :geom_simple, using: :gist, name: 'index_classification_polygons_on_geom_simple'

    # Fix Geometries
    execute <<~SQL.squish
      ALTER TABLE geometries DROP CONSTRAINT check_geom_type;
      ALTER TABLE geometries DROP CONSTRAINT check_geom_simple_validity;
      ALTER TABLE geometries DROP CONSTRAINT check_geom_simple_type;

      DROP INDEX IF EXISTS index_geometries_on_geom_simple;
      DROP INDEX IF EXISTS index_geometries_on_geom_simple_geography;
    SQL

    change_table :geometries, bulk: true do |t|
      t.remove :geom_simple
      t.virtual :geom_simple, type: :geometry, srid: 4326, stored: true, as: 'ST_MakeValid(ST_GeomFromText(ST_AsText(ST_Simplify(ST_Force2d(geom), 0.00001, true), 5)))'
    end

    add_index :geometries, :geom_simple, using: :gist, name: 'index_geometries_on_geom_simple'
    add_index :geometries, 'geography(geom_simple)', using: :gist, name: 'index_geometries_on_geom_simple_geography'
  end
end

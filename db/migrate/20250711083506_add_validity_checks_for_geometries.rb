# frozen_string_literal: true

class AddValidityChecksForGeometries < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;
    SQL

    change_table :geometries, bulk: true do |t|
      t.remove :geom_simple
      t.virtual :geom_simple, type: :geometry, srid: 4326, index: { using: :gist }, stored: true, as: 'ST_MakeValid(ST_GeomFromText(ST_AsText(ST_Simplify(ST_Force2d(geom), 0.00001, true), 5)))'

      t.check_constraint 'ST_IsValid(geom, 0)', name: 'check_geom_validity', validate: false
      t.index 'geography(geom_simple)', using: :gist, name: 'index_geometries_on_geom_simple_geography'
    end

    change_table :classification_polygons, bulk: true do |t|
      t.check_constraint 'ST_IsValid(geom, 0)', name: 'check_geom_validity', validate: false

      t.remove :geog
      t.virtual :geom_simple, type: :geometry, srid: 4326, index: { using: :gist }, stored: true, as: 'ST_MakeValid(ST_GeomFromText(ST_AsText(ST_Simplify(ST_Force2d(geom), 0.00001, true), 5)))'
    end
  end

  def down
  end
end

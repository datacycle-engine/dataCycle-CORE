# frozen_string_literal: true

class UpdateColumnGeomSimpleInGeometriesTable < ActiveRecord::Migration[7.1]
  def change
    remove_column :geometries, :geom_simple, type: :geometry, srid: 4326, index: { using: :gist }, stored: true, as: 'ST_SIMPLIFY(ST_FORCE2D(geom), 0.00001, true)'

    change_table :geometries do |t|
      t.virtual :geom_simple, type: :geometry, srid: 4326, index: { using: :gist }, stored: true, as: 'ST_GeomFromText(ST_AsText(ST_Simplify(ST_Force2d(geom), 0.00001, true), 5))'
    end
  end
end

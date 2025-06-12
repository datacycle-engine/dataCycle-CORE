# frozen_string_literal: true

class MoveGeoColumnsToGeometriesTable < ActiveRecord::Migration[7.1]
  def change
    create_table :geometries, id: :uuid do |t|
      t.references :thing, foreign_key: { on_delete: :cascade }, type: :uuid, null: false
      t.string :relation, null: false
      t.geometry :geom, srid: 4326, has_z: true, null: false
      t.virtual :geom_simple, type: :geometry, srid: 4326, index: { using: :gist }, stored: true, as: 'ST_SIMPLIFY(ST_FORCE2D(geom), 0.00001, true)'
      t.integer :priority, null: false
      t.check_constraint 'priority > 0'
      t.boolean :is_primary, null: false, default: false

      t.index [:thing_id, :relation], unique: true
      t.index [:thing_id, :priority]
      t.index [:thing_id, :is_primary], where: 'is_primary = true'
      t.index 'CAST(geom_simple AS geography)', using: :gist, name: 'index_geometries_on_geom_simple_geography'
      t.unique_constraint [:thing_id, :is_primary], deferrable: :deferred
      t.unique_constraint [:thing_id, :priority], deferrable: :deferred
    end

    create_table :geometry_histories, id: :uuid do |t|
      t.references :thing_history, foreign_key: { on_delete: :cascade }, type: :uuid, null: false
      t.string :relation, null: false
      t.geometry :geom, srid: 4326, has_z: true, null: false
      t.virtual :geom_simple, type: :geometry, srid: 4326, stored: true, as: 'ST_SIMPLIFY(ST_FORCE2D(geom), 0.00001, true)'
      t.integer :priority, null: false
      t.boolean :is_primary, null: false, default: false

      t.index [:thing_history_id, :relation]
    end
  end
end

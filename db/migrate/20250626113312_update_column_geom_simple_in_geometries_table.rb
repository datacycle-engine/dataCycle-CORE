class UpdateColumnGeomSimpleInGeometriesTable < ActiveRecord::Migration[7.1]
  def change
    remove_column :geometries, :geom_simple

    change_table :geometries do |t|
      t.virtual :geom_simple, type: :geometry, srid: 4326, index: { using: :gist }, stored: true, as: 'ST_GeomFromText(ST_AsText(st_simplify(st_force2d(geom), (0.00001)::double precision, true),5))'
    end
  end
end

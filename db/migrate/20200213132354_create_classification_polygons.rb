# frozen_string_literal: true

class CreateClassificationPolygons < ActiveRecord::Migration[5.2]
  def change
    create_table :classification_polygons, id: :uuid do |t|
      t.integer :admin_level
      t.uuid :classification_alias_id
      t.multi_polygon :geom, limit: { srid: 3035 }
      t.multi_polygon :geog, limit: { geographic: true }

      t.timestamps
      t.index ['geom'], name: 'classification_polygons_geom_idx', using: :gist
    end
  end
end

# frozen_string_literal: true

class AddIndexForGeographyGeomSimpleOnThings < ActiveRecord::Migration[6.1]
  def change
    add_index :things, 'geography(geom_simple)', name: :things_geom_simple_geography_idx, using: 'gist', if_not_exists: true
  end
end

# frozen_string_literal: true

class AddGeometryIndexAgain < ActiveRecord::Migration[7.1]
  def change
    add_index :geometries, 'geography(geom_simple)', using: :gist, name: 'index_geometries_on_geom_simple_geography', if_not_exists: true
  end
end

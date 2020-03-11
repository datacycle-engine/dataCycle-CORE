# frozen_string_literal: true

class SpatialIndexOnThingsAndIndexOnClassifications < ActiveRecord::Migration[5.2]
  def change
    add_index :things, :location, name: 'index_things_on_location_spatial', using: 'gist'
    add_index :classifications, :external_key
  end
end

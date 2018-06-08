# frozen_string_literal: true

class AddGeoLine < ActiveRecord::Migration[5.0]
  def change
    add_column :places, :line, :line_string, geographic: true, srid: 4326, has_z: true
    add_column :places, :content, :jsonb
  end
end

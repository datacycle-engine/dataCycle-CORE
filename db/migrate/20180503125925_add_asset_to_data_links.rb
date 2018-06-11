# frozen_string_literal: true

class AddAssetToDataLinks < ActiveRecord::Migration[5.0]
  def change
    add_column :assets, :name, :string
    add_column :data_links, :asset_id, :uuid
    add_index :data_links, :asset_id
  end
end

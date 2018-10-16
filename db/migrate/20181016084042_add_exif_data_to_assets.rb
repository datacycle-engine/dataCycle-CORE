# frozen_string_literal: true

class AddExifDataToAssets < ActiveRecord::Migration[5.1]
  def up
    add_column :assets, :exif_data, :jsonb
  end

  def down
    remove_column :assets, :exif_data
  end
end

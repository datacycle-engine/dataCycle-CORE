# frozen_string_literal: true

class AddMetaDataToAssets < ActiveRecord::Migration[5.1]
  def up
    add_column :assets, :metadata, :jsonb
    add_column :assets, :duplicate_check, :jsonb
  end

  def down
    remove_column :assets, :metadata
    remove_column :assets, :duplicate_check
  end
end

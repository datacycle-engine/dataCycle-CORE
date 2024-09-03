# frozen_string_literal: true

class AddForeignKeysAndUniqueContraintsForAssetContents < ActiveRecord::Migration[6.1]
  def change
    remove_index :asset_contents, :asset_id, name: 'index_asset_contents_on_asset_id', if_exists: true
    remove_index :asset_contents, :content_data_id, name: 'index_asset_contents_on_content_data_id', if_exists: true

    remove_column :asset_contents, :seen_at, :datetime, if_exists: true
    remove_column :asset_contents, :content_data_type, :string
    rename_column :asset_contents, :content_data_id, :thing_id

    change_column_null :asset_contents, :thing_id, false
    change_column_null :asset_contents, :asset_id, false

    add_foreign_key :asset_contents, :things, on_delete: :cascade
    add_foreign_key :asset_contents, :assets, on_delete: :cascade

    add_index :asset_contents, [:thing_id, :relation], unique: true, if_not_exists: true
    add_index :asset_contents, :asset_id, unique: true, if_not_exists: true
  end
end

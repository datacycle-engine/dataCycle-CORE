# frozen_string_literal: true

class CreateAssetContentsRelation < ActiveRecord::Migration[5.0]
  def up
    create_table :asset_contents, id: :uuid do |t|
      t.uuid :content_data_id
      t.string :content_data_type
      t.uuid :asset_id
      t.string :asset_type
      t.string :relation
      t.datetime :seen_at
      t.timestamps
    end

    add_index :asset_contents, :asset_id
    add_index :asset_contents, :content_data_id
  end

  def down
    drop_table :asset_contents
    remove_index :asset_contents, :asset_id
    remove_index :asset_contents, :content_data_id
  end
end

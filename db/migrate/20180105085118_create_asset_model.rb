# frozen_string_literal: true

class CreateAssetModel < ActiveRecord::Migration[5.0]
  def up
    create_table :assets, id: :uuid do |t|
      t.string :file
      t.string :type
      t.string :content_type
      t.integer :file_size
      t.uuid :creator_id
      t.timestamps
      t.datetime :seen_at
    end
  end

  def down
    drop_table :assets
  end
end

# frozen_string_literal: true

class CreateEditLinks < ActiveRecord::Migration[5.0]
  def up
    create_table :edit_links, id: :uuid do |t|
      t.uuid :item_id
      t.string :item_type
      t.uuid :creator_id
      t.boolean :read_only, default: true, null: false
      t.datetime :seen_at
      t.timestamps
      t.index :item_id
      t.index :item_type
    end
  end

  def down
    drop_table :edit_links
  end
end

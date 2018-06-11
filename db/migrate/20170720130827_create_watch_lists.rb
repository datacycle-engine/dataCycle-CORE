# frozen_string_literal: true

class CreateWatchLists < ActiveRecord::Migration[5.0]
  def up
    create_table :watch_lists, id: :uuid do |t|
      t.string :headline
      t.uuid :user_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :watch_list_data_hashes, id: :uuid do |t|
      t.uuid :watch_list_id
      t.uuid :hashable_id
      t.string :hashable_type
      t.datetime :seen_at
      t.timestamps
      t.index :watch_list_id
      t.index :hashable_id
      t.index :hashable_type
    end
  end

  def down
    drop_table :watch_lists
    drop_table :watch_list_data_hashes
  end
end

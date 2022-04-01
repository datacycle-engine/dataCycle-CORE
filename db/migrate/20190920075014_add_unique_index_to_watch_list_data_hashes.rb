# frozen_string_literal: true

class AddUniqueIndexToWatchListDataHashes < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      DELETE FROM watch_list_data_hashes a
      USING watch_list_data_hashes b
      WHERE a.id > b.id
      AND a.watch_list_id = b.watch_list_id
      AND a.hashable_id = b.hashable_id
      AND a.hashable_type = b.hashable_type
    SQL

    add_index :watch_list_data_hashes, [:watch_list_id, :hashable_id, :hashable_type], unique: true, name: 'by_watch_list_hashable'
  end

  def down
    remove_index :watch_list_data_hashes, name: 'by_watch_list_hashable'
  end
end

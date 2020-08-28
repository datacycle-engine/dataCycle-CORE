# frozen_string_literal: true

class ChangeFieldsForWatchlists < ActiveRecord::Migration[5.2]
  def up
    add_column :watch_lists, :full_path, :string
    add_column :watch_lists, :full_path_names, :string, array: true

    execute <<-SQL
      CREATE INDEX full_path_idx ON watch_lists USING GIN (full_path gin_trgm_ops);
    SQL

    execute <<-SQL
      UPDATE watch_lists
      SET full_path = name;
    SQL
  end

  def down
    execute <<-SQL
      UPDATE watch_lists
      SET name = full_path;
    SQL

    remove_column :watch_lists, :full_path
    remove_index :watch_lists, :full_path, name: 'full_path_idx' if index_exists?(:watch_lists, :full_path, name: 'full_path_idx')
    remove_column :watch_lists, :full_path_names
  end
end

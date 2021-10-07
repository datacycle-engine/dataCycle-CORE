# frozen_string_literal: true

class AddColumnForMySelectionToWatchLists < ActiveRecord::Migration[5.2]
  def up
    add_column :watch_lists, :my_selection, :boolean, default: false, null: false

    execute <<~SQL.squish
      INSERT INTO watch_lists(name, user_id, created_at, updated_at, full_path, full_path_names, my_selection)
      SELECT 'Meine Auswahl', users.id, NOW(), NOW(), 'Meine Auswahl', ARRAY[]::VARCHAR[], TRUE
      FROM users
    SQL
  end

  def down
    execute <<~SQL.squish
      DELETE FROM watch_lists
      WHERE my_selection = TRUE;
    SQL

    remove_column :watch_lists, :my_selection
  end
end

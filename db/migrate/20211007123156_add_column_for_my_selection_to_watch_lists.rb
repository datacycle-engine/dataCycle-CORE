# frozen_string_literal: true

class AddColumnForMySelectionToWatchLists < ActiveRecord::Migration[5.2]
  def up
    add_column :watch_lists, :my_selection, :boolean, default: false, null: false

    execute <<~SQL.squish
      INSERT INTO watch_lists (name, user_id, created_at, updated_at, full_path, full_path_names, my_selection)
      SELECT
        'Meine Auswahl',
        users.id,
        NOW(),
        NOW(),
        'Meine Auswahl',
        ARRAY[]::varchar[],
        TRUE
      FROM
        users;

      CREATE OR REPLACE FUNCTION generate_my_selection_watch_list ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        INSERT INTO watch_lists (name, user_id, created_at, updated_at, full_path, full_path_names, my_selection)
        SELECT
          'Meine Auswahl',
          users.id,
          NOW(),
          NOW(),
          'Meine Auswahl',
          ARRAY[]::varchar[],
          TRUE
        FROM
          users
          INNER JOIN roles ON roles.id = users.role_id
        WHERE
          users.id = NEW.id
          AND roles.rank <> 0;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER generate_my_selection_watch_list
        AFTER INSERT ON users
        FOR EACH ROW
        EXECUTE FUNCTION generate_my_selection_watch_list ();
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP TRIGGER generate_my_selection_watch_list ON users;

      DROP FUNCTION generate_my_selection_watch_list;

      DELETE FROM watch_lists
      WHERE my_selection = TRUE;
    SQL

    remove_column :watch_lists, :my_selection
  end
end

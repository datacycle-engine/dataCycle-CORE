# frozen_string_literal: true

class AddTriggerForMySelectionAfterRoleChange < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL.squish
      INSERT INTO watch_lists (
        name,
        user_id,
        created_at,
        updated_at,
        full_path,
        full_path_names,
        my_selection)
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
        roles.rank <> 0
        AND NOT EXISTS (
          SELECT
          FROM
            watch_lists
          WHERE
            watch_lists.my_selection
            AND watch_lists.user_id = users.id);

      CREATE OR REPLACE FUNCTION generate_my_selection_watch_list ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        IF EXISTS (
          SELECT
          FROM
            roles
          WHERE
            roles.id = NEW.role_id
            AND roles.rank <> 0) THEN
        INSERT INTO watch_lists (
          name,
          user_id,
          created_at,
          updated_at,
          full_path,
          full_path_names,
          my_selection)
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
          AND roles.rank <> 0
          AND NOT EXISTS (
            SELECT
            FROM
              watch_lists
            WHERE
              watch_lists.my_selection
              AND watch_lists.user_id = users.id);
      ELSE
        DELETE FROM watch_lists
        WHERE watch_lists.user_id = NEW.id
          AND watch_lists.my_selection;
      END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER update_my_selection_watch_list
        AFTER UPDATE OF role_id ON users
        FOR EACH ROW
        WHEN (OLD.role_id IS DISTINCT FROM NEW.role_id)
        EXECUTE FUNCTION generate_my_selection_watch_list ();
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP TRIGGER update_my_selection_watch_list ON users;
    SQL
  end
end

# frozen_string_literal: true

class ChangeFieldsForWatchlists < ActiveRecord::Migration[5.2]
  def up
    add_column :watch_lists, :full_path, :string
    add_column :watch_lists, :full_path_names, :string, array: true

    execute <<-SQL
      CREATE OR REPLACE FUNCTION update_watch_lists_full_path_names_and_name()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS
      $$
      BEGIN
        IF NEW.full_path <> OLD.full_path OR OLD.full_path IS NULL THEN
          NEW.name = (string_to_array(NEW.full_path, '/'))[array_length(string_to_array(NEW.full_path, '/'), 1)];
          NEW.full_path_names = (string_to_array(NEW.full_path, '/'))[1:array_length(string_to_array(NEW.full_path, '/'), 1) - 1];
        END IF;

        RETURN NEW;
      END;
      $$;
    SQL

    execute <<-SQL
      CREATE TRIGGER watchlistfullpathnames BEFORE INSERT OR UPDATE
      ON watch_lists FOR EACH ROW EXECUTE PROCEDURE
      update_watch_lists_full_path_names_and_name();
    SQL

    execute <<-SQL
      UPDATE watch_lists
      SET full_path = name;
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS watchlistfullpathnames
      ON watch_lists;
    SQL

    execute <<-SQL
      DROP FUNCTION IF EXISTS update_watch_lists_full_path_names_and_name;
    SQL

    remove_column :watch_lists, :full_path
    remove_column :watch_lists, :full_path_names
  end
end

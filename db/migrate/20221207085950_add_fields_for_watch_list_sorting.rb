# frozen_string_literal: true

class AddFieldsForWatchListSorting < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE watch_lists ADD COLUMN manual_order BOOLEAN NOT NULL DEFAULT FALSE;
      ALTER TABLE watch_list_data_hashes ADD COLUMN order_a INTEGER NOT NULL DEFAULT 1;
      ALTER TABLE watch_list_data_hashes ALTER COLUMN created_at SET DEFAULT transaction_timestamp();
      ALTER TABLE watch_list_data_hashes ALTER COLUMN updated_at SET DEFAULT transaction_timestamp();
      CREATE INDEX wldh_order_a_idx ON watch_list_data_hashes(order_a);

      CREATE OR REPLACE FUNCTION wldh_order_a_default_value ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        NEW.order_a := (SELECT (count(watch_list_data_hashes.id) + 1) FROM watch_list_data_hashes WHERE watch_list_data_hashes.watch_list_id = NEW.watch_list_id);
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER wldh_order_a_default_value_trigger
        BEFORE INSERT ON watch_list_data_hashes
        FOR EACH ROW
        EXECUTE FUNCTION wldh_order_a_default_value ();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP INDEX wldh_order_a_idx;
      ALTER TABLE watch_lists DROP COLUMN manual_order;
      ALTER TABLE watch_list_data_hashes DROP COLUMN order_a;
      ALTER TABLE watch_list_data_hashes ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE watch_list_data_hashes ALTER COLUMN updated_at DROP DEFAULT;

      DROP TRIGGER wldh_order_a_default_value_trigger ON watch_list_data_hashes;
      DROP FUNCTION wldh_order_a_default_value;
    SQL
  end
end

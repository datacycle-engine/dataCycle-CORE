# frozen_string_literal: true

class RefactorTriggerForWatchListDataHashDefaultOrderValue < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE watch_list_data_hashes ALTER COLUMN order_a DROP NOT NULL;
      ALTER TABLE watch_list_data_hashes ALTER COLUMN order_a DROP DEFAULT;
      DROP TRIGGER IF EXISTS wldh_order_a_default_value_trigger ON watch_list_data_hashes;
      DROP FUNCTION IF EXISTS wldh_order_a_default_value;
      DROP INDEX IF EXISTS wldh_order_a_idx;
      CREATE INDEX wldh_order_a_brin_idx ON watch_list_data_hashes USING brin(order_a, created_at);
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS wldh_order_a_default_value_trigger ON watch_list_data_hashes;
      DROP FUNCTION IF EXISTS update_wldh_order_a_value;
      DROP INDEX IF EXISTS wldh_order_a_brin_idx;
      CREATE INDEX wldh_order_a_idx ON watch_list_data_hashes(order_a);

      ALTER TABLE watch_list_data_hashes ALTER COLUMN order_a SET DEFAULT 1;

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
end

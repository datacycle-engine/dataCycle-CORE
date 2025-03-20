# frozen_string_literal: true

class CreateThingHistoryLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :thing_history_links, id: :uuid do |t|
      t.uuid :thing_id, null: false
      t.uuid :thing_history_id, null: false
      t.timestamps
    end

    add_index :thing_history_links, [:thing_id, :thing_history_id], unique: true

    add_foreign_key :thing_history_links, :things, column: :thing_id, on_delete: :cascade
    add_foreign_key :thing_history_links, :thing_histories, column: :thing_history_id, on_delete: :cascade

    create_table :thing_history_link_histories, id: :uuid do |t|
      t.uuid :thing_history_link_id, null: false
      t.uuid :thing_id, null: false
      t.uuid :thing_history_id, null: false
      t.timestamp :created_at
      t.timestamp :updated_at
      t.timestamp :deleted_at
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE OR REPLACE FUNCTION thing_history_links_deletion_trigger_function()
          RETURNS TRIGGER AS $$
          BEGIN
            INSERT INTO thing_history_link_histories (
              thing_history_link_id,
              thing_id,
              thing_history_id,
              deleted_at,
              updated_at,
              created_at
            )
            VALUES (
              OLD.id,
              OLD.thing_id,
              OLD.thing_history_id,
              NOW(),
              NOW(),
              OLD.created_at
            );
            RETURN OLD;
          END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE FUNCTION thing_history_links_update_trigger_function()
          RETURNS TRIGGER AS $$
          BEGIN
            INSERT INTO thing_history_link_histories (
              thing_history_link_id,
              thing_id,
              thing_history_id,
              updated_at,
              created_at
            )
            VALUES (
              OLD.id,
              OLD.thing_id,
              OLD.thing_history_id,
              OLD.updated_at,
              OLD.created_at
            );
            RETURN OLD;
          END;
          $$ LANGUAGE plpgsql;

          CREATE TRIGGER trigger_delete_thing_history_links
          AFTER DELETE ON thing_history_links
          FOR EACH ROW
          EXECUTE FUNCTION thing_history_links_deletion_trigger_function();

          CREATE TRIGGER trigger_update_thing_history_links
          AFTER UPDATE ON thing_history_links
          FOR EACH ROW
          EXECUTE FUNCTION thing_history_links_update_trigger_function();
        SQL
      end

      dir.down do
        execute <<~SQL
          DROP TRIGGER IF EXISTS trigger_delete_thing_history_links ON thing_history_links;
          DROP FUNCTION IF EXISTS thing_history_links_deletion_trigger_function();
          DROP TRIGGER IF EXISTS trigger_update_thing_history_links ON thing_history_links;
          DROP FUNCTION IF EXISTS thing_history_links_update_trigger_function();
        SQL
      end
    end
  end
end

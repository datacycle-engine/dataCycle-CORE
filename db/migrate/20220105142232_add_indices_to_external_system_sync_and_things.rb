# frozen_string_literal: true

class AddIndicesToExternalSystemSyncAndThings < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      CREATE INDEX IF NOT EXISTS index_things_on_external_key ON things (external_key);
      CREATE INDEX IF NOT EXISTS index_external_system_syncs_on_syncalbe_id_and_external_key ON external_system_syncs (syncable_id, external_key);
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP INDEX IF EXISTS index_things_on_external_key;
      DROP INDEX IF EXISTS index_external_system_syncs_on_syncalbe_id_and_external_key;
    SQL
  end
end

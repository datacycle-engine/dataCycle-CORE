# frozen_string_literal: true

class AddGinIndizesForIdSearch < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;

      CREATE INDEX IF NOT EXISTS index_things_on_id_gin ON things USING gin ((id::VARCHAR) gin_trgm_ops);
      CREATE INDEX IF NOT EXISTS index_things_on_external_key_gin ON things USING gin (external_key gin_trgm_ops);
      CREATE INDEX IF NOT EXISTS index_ess_on_external_key_gin ON external_system_syncs USING gin (external_key gin_trgm_ops);
    SQL
  end

  def down
    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;

      DROP INDEX IF EXISTS index_things_on_id_gin;
      DROP INDEX IF EXISTS index_things_on_external_key_gin;
      DROP INDEX IF EXISTS index_ess_on_external_key_gin ;
    SQL
  end
end

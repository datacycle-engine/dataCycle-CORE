# frozen_string_literal: true

class AddGinIndexForThingTranslationsName < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;
      CREATE INDEX IF NOT EXISTS thing_translations_name_gin_idx ON thing_translations USING gin ((content->>'name'::text) gin_trgm_ops);
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP INDEX IF EXISTS thing_translations_name_gin_idx;
    SQL
  end
end

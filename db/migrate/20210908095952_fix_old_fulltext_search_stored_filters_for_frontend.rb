# frozen_string_literal: true

class FixOldFulltextSearchStoredFiltersForFrontend < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      UPDATE stored_filters
      SET parameters = REPLACE( parameters::TEXT, '"t": "fulltext_search"'::TEXT, '"t": "fulltext_search", "c": "a"'::TEXT )::JSONB
      WHERE parameters::TEXT ILIKE '%"t": "fulltext_search"%'
      AND parameters::TEXT NOT ILIKE '%"c": "a"%"t": "fulltext_search"%'
    SQL
  end

  def down
  end
end

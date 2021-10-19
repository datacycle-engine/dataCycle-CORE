# frozen_string_literal: true

class RunInitialProcedureForTypeahead < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      UPDATE
        searches
      SET
        words_typeahead = to_tsvector('pg_catalog.simple', full_text);
    SQL
  end

  def down
  end
end

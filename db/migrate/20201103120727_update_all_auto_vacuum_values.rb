# frozen_string_literal: true

class UpdateAllAutoVacuumValues < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      ANALYZE;
    SQL

    tables.each do |table|
      execute <<-SQL.squish
        ALTER TABLE #{table} SET (autovacuum_vacuum_scale_factor = 0, autovacuum_vacuum_threshold = 100, autovacuum_analyze_scale_factor = 0, autovacuum_analyze_threshold = 50);
      SQL
    end
  end

  def down
    query = <<-SQL.squish
      UPDATE pg_class
      SET reloptions = NULL
      WHERE relname IN (?)
    SQL

    execute(ActiveRecord::Base.sanitize_sql_for_conditions([query, tables]))

    execute <<-SQL.squish
      ANALYZE;
    SQL
  end
end

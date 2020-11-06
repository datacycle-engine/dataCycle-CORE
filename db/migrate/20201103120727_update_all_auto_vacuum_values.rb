# frozen_string_literal: true

class UpdateAllAutoVacuumValues < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute('ANALYZE;')
    execute('VACUUM;')

    query = <<-SQL.squish
      UPDATE pg_class
      SET reloptions = NULL
      WHERE relname IN (?)
    SQL

    execute(ActiveRecord::Base.sanitize_sql_for_conditions([query, tables]))

    execute <<-SQL.squish
      ALTER SYSTEM SET autovacuum_vacuum_scale_factor = 0;
    SQL

    execute <<-SQL.squish
      ALTER SYSTEM SET autovacuum_vacuum_threshold = 100;
    SQL

    execute <<-SQL.squish
      ALTER SYSTEM SET autovacuum_analyze_scale_factor = 0;
    SQL

    execute <<-SQL.squish
      ALTER SYSTEM SET autovacuum_analyze_threshold = 100;
    SQL

    execute('SELECT pg_reload_conf();')
  end

  def down
    execute <<-SQL.squish
      ALTER SYSTEM RESET autovacuum_vacuum_scale_factor;
    SQL

    execute <<-SQL.squish
      ALTER SYSTEM RESET autovacuum_vacuum_threshold;
    SQL

    execute <<-SQL.squish
      ALTER SYSTEM RESET autovacuum_analyze_scale_factor;
    SQL

    execute <<-SQL.squish
      ALTER SYSTEM RESET autovacuum_analyze_threshold;
    SQL

    execute('SELECT pg_reload_conf();')
    execute('ANALYZE;')
  end
end

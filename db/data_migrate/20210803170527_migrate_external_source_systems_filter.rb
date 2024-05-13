# frozen_string_literal: true

class MigrateExternalSourceSystemsFilter < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    return unless ActiveRecord::Base.connection.table_exists? 'stored_filters'
    # external source filters
    execute <<-SQL
        UPDATE stored_filters
        SET parameters = REPLACE( parameters::TEXT, '"n": "External_source", "t": "external_source"'::TEXT, '"n": "External_system", "q": "import", "t": "external_system"'::TEXT )::JSONB
        WHERE parameters::TEXT ILIKE '%"n": "External_source", "t": "external_source"%'
    SQL

    # external_system filters
    execute <<-SQL
        UPDATE stored_filters
        SET parameters = REPLACE( parameters::TEXT, '"n": "External_system", "t": "external_system"'::TEXT, '"n": "External_system", "q": "export", "t": "external_system"'::TEXT )::JSONB
        WHERE parameters::TEXT ILIKE '%"n": "External_system", "t": "external_system"%'
    SQL
  end

  def down
  end
end

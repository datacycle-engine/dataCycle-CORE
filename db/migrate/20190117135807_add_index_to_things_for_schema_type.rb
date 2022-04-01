# frozen_string_literal: true

class AddIndexToThingsForSchemaType < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_things_on_schema_type ON things ((schema ->> 'schema_type'));
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX IF EXISTS index_things_on_schema_type;
    SQL
  end
end

# frozen_string_literal: true

class RebuildComputedSchemaTypes < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE things
      SET cache_valid_since = NOW(),
          computed_schema_types = compute_thing_schema_types(
          things.schema->'schema_ancestors',
          things.template_name
        );
    SQL
  end

  def down
  end
end

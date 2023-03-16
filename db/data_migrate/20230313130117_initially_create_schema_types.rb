# frozen_string_literal: true

class InitiallyCreateSchemaTypes < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE things
      SET computed_schema_types = compute_thing_schema_types(
          things.schema->'schema_ancestors',
          things.template_name
        )
      WHERE things.computed_schema_types IS NULL;
    SQL
  end

  def down
  end
end

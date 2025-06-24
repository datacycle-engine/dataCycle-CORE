# frozen_string_literal: true

class ChangeThingTemplateComputedSchemaTypesToNormalColumn < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;
    SQL

    change_table :thing_templates, bulk: true do |t|
      t.remove :computed_schema_types
      t.string :api_schema_types, default: [], null: false, array: true
      t.remove :content_type
      t.string :content_type, index: true
      t.remove :boost
      t.integer :boost, index: true
    end

    change_column :things, :boost, :integer, default: 1
    change_column :thing_histories, :boost, :integer, default: 1

    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS public.compute_thing_schema_types(schema_types jsonb, template_name character varying);
    SQL
  end

  def down
  end
end

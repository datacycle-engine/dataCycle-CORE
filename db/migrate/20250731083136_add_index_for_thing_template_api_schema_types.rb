# frozen_string_literal: true

class AddIndexForThingTemplateApiSchemaTypes < ActiveRecord::Migration[7.1]
  def change
    change_table :thing_templates, bulk: true do |t|
      t.index :api_schema_types, using: :gin, name: 'index_thing_templates_on_api_schema_types'
      t.index "(schema -> 'properties' -> 'data_type' ->> 'default_value')", name: 'index_thing_templates_on_data_type_default_value'
    end
  end
end

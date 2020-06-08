# frozen_string_literal: true

class AddFieldTemplateNameAndSchema < ActiveRecord::Migration[5.0]
  def up
    ['creative_works', 'events', 'persons', 'places'].each do |table_name|
      next unless @connection.table_exists?(table_name)

      add_column table_name.to_sym, :template_name, :string
      add_column table_name.to_sym, :schema, :jsonb
      add_column (table_name.singularize + '_histories').to_sym, :template_name, :string
      add_column (table_name.singularize + '_histories').to_sym, :schema, :jsonb
    end
  end

  def down
    ['creative_works', 'events', 'persons', 'places'].each do |table_name|
      next unless @connection.table_exists?(table_name)

      remove_column table_name.to_sym, :template_name, :string
      remove_column table_name.to_sym, :schema, :jsonb
      remove_column (table_name.singularize + '_histories').to_sym, :template_name, :string
      remove_column (table_name.singularize + '_histories').to_sym, :schema, :jsonb
    end
  end
end

class AddFieldTemplateNameAndSchema < ActiveRecord::Migration[5.0]
  def up
    DataCycleCore.content_tables.each do |table_name|
      add_column table_name.to_sym, :template_name, :string
      add_column table_name.to_sym, :schema, :jsonb
      add_column (table_name.singularize + '_histories').to_sym, :template_name, :string
      add_column (table_name.singularize + '_histories').to_sym, :schema, :jsonb
    end
  end

  def down
    DataCycleCore.content_tables.each do |table_name|
      remove_column table_name.to_sym, :template_name, :string
      remove_column table_name.to_sym, :schema, :jsonb
      remove_column (table_name.singularize + '_histories').to_sym, :template_name, :string
      remove_column (table_name.singularize + '_histories').to_sym, :schema, :jsonb
    end
  end
end
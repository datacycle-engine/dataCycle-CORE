# frozen_string_literal: true

class AddUserFieldsToContentTables < ActiveRecord::Migration[5.1]
  def change
    (DataCycleCore.content_tables - ['things'] + ['organizations']).each do |content_table|
      add_column content_table.to_sym, :created_by, :uuid
      add_column content_table.to_sym, :updated_by, :uuid
      add_column content_table.to_sym, :deleted_by, :uuid
      add_column content_table.to_sym, :deleted_at, :datetime
      add_column (content_table.singularize + '_histories').to_sym, :created_by, :uuid
      add_column (content_table.singularize + '_histories').to_sym, :updated_by, :uuid
      add_column (content_table.singularize + '_histories').to_sym, :deleted_by, :uuid
    end
  end
end

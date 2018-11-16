# frozen_string_literal: true

class AddAdditionalColumnsToExternalSources < ActiveRecord::Migration[5.1]
  def up
    add_column :external_sources, :config_out, :jsonb
    add_column :external_sources, :data, :jsonb
  end

  def down
    remove_column :external_sources, :config_out, :jsonb
    remove_column :external_sources, :data, :jsonb
  end
end

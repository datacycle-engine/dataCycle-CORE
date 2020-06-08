# frozen_string_literal: true

class RemovePropertiesColumnFromAllContentTables < ActiveRecord::Migration[5.0]
  def change
    remove_column :event_translations, :properties, :jsonb
    remove_column :event_history_translations, :properties, :jsonb
    remove_column :creative_work_translations, :properties, :jsonb
    remove_column :creative_work_history_translations, :properties, :jsonb
    remove_column :organization_translations, :properties, :jsonb
    remove_column :organization_history_translations, :properties, :jsonb
    remove_column :person_translations, :properties, :jsonb
    remove_column :person_history_translations, :properties, :jsonb
    remove_column :place_translations, :properties, :jsonb
    remove_column :place_history_translations, :properties, :jsonb
  end
end

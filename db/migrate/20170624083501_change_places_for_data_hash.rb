# frozen_string_literal: true

class ChangePlacesForDataHash < ActiveRecord::Migration[5.0]
  def change
    rename_column :places, :content, :metadata
    add_column :places, :template, :boolean, default: false
    add_column :places, :headline, :string

    reversible do |dir|
      dir.up do
        change_column :places, :description, :text
      end
      dir.down do
        change_column :places, :description, :string
      end
    end

    # remove_column :place_translations, :description, :text
    add_column :place_translations, :content, :jsonb
    add_column :place_translations, :properties, :jsonb
  end
end

class ChangePlacesForDataHash < ActiveRecord::Migration[5.0]
  def change
    rename_column :places, :content, :metadata
    add_column :places, :template, :boolean, default: false
    add_column :places, :headline, :string
    add_column :places, :description, :text

    add_column :place_translations, :content, :jsonb
    add_column :place_translations, :properties, :jsonb
  end
end

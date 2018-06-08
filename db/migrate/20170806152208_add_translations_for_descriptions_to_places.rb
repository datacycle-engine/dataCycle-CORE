# frozen_string_literal: true

class AddTranslationsForDescriptionsToPlaces < ActiveRecord::Migration[5.0]
  def up
    add_column :place_translations, :description, :text
    remove_column :places, :description
  end

  def down
    remove_column :place_translations, :description
    add_column :places, :description, :text
  end
end

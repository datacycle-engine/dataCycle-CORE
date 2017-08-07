class AddTranslationsForDescriptionsToPlaces < ActiveRecord::Migration[5.0]
  def up
    DataCycleCore::Place.add_translation_fields! description: :text   
    remove_column :places, :description
  end

  def down
    remove_column :place_translations, :description
    add_column :places, :description, :text
  end
end

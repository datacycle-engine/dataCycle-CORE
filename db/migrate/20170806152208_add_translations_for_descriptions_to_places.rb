class AddTranslationsForDescriptionsToPlaces < ActiveRecord::Migration[5.0]
  def up
    DataCycleCore::Place.add_translation_fields! description: :text    
  end

  def down
    remove_column :place_translations, :description
  end
end

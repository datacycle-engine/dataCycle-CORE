class AddAddressTranslationToPlaces < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      dir.up do
        DataCycleCore::Place.add_translation_fields! address: :string
      end

      dir.down do
        remove_column :place_translations, :address
      end
    end
  end
end

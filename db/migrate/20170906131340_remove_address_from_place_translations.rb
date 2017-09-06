class RemoveAddressFromPlaceTranslations < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      dir.up do
        remove_column :place_translations, :address
      end

      dir.down do
        DataCycleCore::Place.add_translation_fields! address: :string
      end
    end
  end
end

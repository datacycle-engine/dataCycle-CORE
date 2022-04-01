# frozen_string_literal: true

class AddAddressTranslationToPlaces < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      dir.up do
        add_column :place_translations, :address, :string
      end

      dir.down do
        remove_column :place_translations, :address
      end
    end
  end
end

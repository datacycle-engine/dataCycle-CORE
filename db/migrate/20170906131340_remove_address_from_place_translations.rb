# frozen_string_literal: true

class RemoveAddressFromPlaceTranslations < ActiveRecord::Migration[5.0]
  def change
    reversible do |dir|
      dir.up do
        remove_column :place_translations, :address
      end

      dir.down do
        add_column :place_translations, :address, :string
      end
    end
  end
end

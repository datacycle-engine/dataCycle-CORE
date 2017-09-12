class RemoveAddressDataFromTranslationsForPlaces < ActiveRecord::Migration[5.0]
  def change
    remove_column :place_translations, :addressLocality, :string
    remove_column :place_translations, :streetAddress, :string
    remove_column :place_translations, :postalCode, :string
    remove_column :place_translations, :addressCountry, :string
    remove_column :place_translations, :faxNumber, :string
    remove_column :place_translations, :telephone, :string
    remove_column :place_translations, :email, :string

    rename_column :place_translations, :hoursAvailable, :hours_available

    add_column :places, :address_locality, :string
    add_column :places, :street_address, :string
    add_column :places, :postal_code, :string
    add_column :places, :address_country, :string
    add_column :places, :fax_number, :string
    add_column :places, :telephone, :string
    add_column :places, :email, :string
  end
end

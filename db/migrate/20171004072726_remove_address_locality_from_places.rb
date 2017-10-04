class RemoveAddressLocalityFromPlaces < ActiveRecord::Migration[5.0]
  def change
    remove_column :places, :addressLocality, :string
  end
end

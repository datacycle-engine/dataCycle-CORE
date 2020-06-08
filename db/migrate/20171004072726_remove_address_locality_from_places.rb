# frozen_string_literal: true

class RemoveAddressLocalityFromPlaces < ActiveRecord::Migration[5.0]
  def change
    remove_column :places, :addressLocality, :string if column_exists? :places, :addressLocality
  end
end

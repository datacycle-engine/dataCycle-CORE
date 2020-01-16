# frozen_string_literal: true

class AddLocaleToDataLinks < ActiveRecord::Migration[5.2]
  def change
    add_column :data_links, :locale, :string
  end
end

# frozen_string_literal: true

class AddDefaultLocaleToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :default_locale, :string, default: 'de'
  end
end

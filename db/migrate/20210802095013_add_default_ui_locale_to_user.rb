# frozen_string_literal: true

class AddDefaultUiLocaleToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :ui_locale, :string, default: 'de', null: false
  end
end

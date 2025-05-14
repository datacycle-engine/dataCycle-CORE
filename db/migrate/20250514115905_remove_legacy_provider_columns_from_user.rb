# frozen_string_literal: true

class RemoveLegacyProviderColumnsFromUser < ActiveRecord::Migration[7.1]
  def change
    change_table :users, bulk: true do |t|
      t.remove :provider, type: :string
      t.remove :uid, type: :string
    end
  end
end

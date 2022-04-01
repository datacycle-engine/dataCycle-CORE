# frozen_string_literal: true

class AddIndexForAdvancedAttributesToSearch < ActiveRecord::Migration[5.2]
  def change
    add_index :searches, :advanced_attributes, using: :gin
  end
end

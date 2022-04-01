# frozen_string_literal: true

class AddAdvancedAttributesToSearch < ActiveRecord::Migration[5.2]
  def change
    add_column :searches, :advanced_attributes, :jsonb
  end
end

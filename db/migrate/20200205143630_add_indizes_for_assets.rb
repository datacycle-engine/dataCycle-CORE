# frozen_string_literal: true

class AddIndizesForAssets < ActiveRecord::Migration[5.2]
  def change
    add_index :assets, :creator_id
    add_index :assets, :type
  end
end

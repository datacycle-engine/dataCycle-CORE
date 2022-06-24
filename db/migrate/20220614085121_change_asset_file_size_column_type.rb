# frozen_string_literal: true

class ChangeAssetFileSizeColumnType < ActiveRecord::Migration[6.1]
  def up
    change_column :assets, :file_size, :bigint
  end

  def down
    change_column :assets, :file_size, :int
  end
end

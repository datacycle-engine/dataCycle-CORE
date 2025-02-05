# frozen_string_literal: true

class RemoveFileColumnFromAssets < ActiveRecord::Migration[7.1]
  def change
    remove_column :assets, :file, :text, if_exists: true
  end
end

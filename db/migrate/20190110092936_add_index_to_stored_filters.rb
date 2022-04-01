# frozen_string_literal: true

class AddIndexToStoredFilters < ActiveRecord::Migration[5.1]
  def up
    add_index :stored_filters, :updated_at
  end

  def down
    remove_index :stored_filters, :updated_at
  end
end

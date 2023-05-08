# frozen_string_literal: true

class AddDeletedAtToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :deleted_at, :timestamp
  end
end

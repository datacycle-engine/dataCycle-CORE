# frozen_string_literal: true

class AddIndexForUserIdDeletedAt < ActiveRecord::Migration[7.1]
  def change
    add_index :users, [:id, :deleted_at], name: 'index_users_on_id_and_deleted_at', where: 'deleted_at IS NULL', unique: true
  end
end

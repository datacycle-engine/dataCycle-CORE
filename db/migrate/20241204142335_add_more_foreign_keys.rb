# frozen_string_literal: true

class AddMoreForeignKeys < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :posts, :users, column: :user_id
  end
end

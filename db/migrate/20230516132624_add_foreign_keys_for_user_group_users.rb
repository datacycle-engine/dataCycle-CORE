# frozen_string_literal: true

class AddForeignKeysForUserGroupUsers < ActiveRecord::Migration[6.1]
  def change
    add_foreign_key :user_group_users, :users, on_delete: :cascade, validate: false
    add_foreign_key :user_group_users, :user_groups, on_delete: :cascade, validate: false
  end
end

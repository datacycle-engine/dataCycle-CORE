# frozen_string_literal: true

class AddForeignKeyConstraintsForUserGroupUsers < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      DELETE FROM user_group_users
      WHERE user_group_users.user_group_id IS NULL OR user_group_users.user_id IS NULL
    SQL

    change_table :user_group_users, bulk: true do |t|
      t.change_null :user_group_id, false
      t.change_null :user_id, false
    end
  end

  def down
  end
end

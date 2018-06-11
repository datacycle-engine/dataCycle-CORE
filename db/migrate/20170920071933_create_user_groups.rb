# frozen_string_literal: true

class CreateUserGroups < ActiveRecord::Migration[5.0]
  def up
    create_table :user_groups, id: :uuid do |t|
      t.string :name
      t.datetime :seen_at
      t.timestamps
      t.index :name
    end

    create_table :user_group_users, id: :uuid do |t|
      t.uuid :user_group_id
      t.uuid :user_id
      t.datetime :seen_at
      t.timestamps
      t.index :user_group_id
      t.index :user_id
    end
  end

  def down
    drop_table :user_group_users
    drop_table :user_groups
  end
end

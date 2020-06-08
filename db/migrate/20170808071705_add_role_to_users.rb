# frozen_string_literal: true

class AddRoleToUsers < ActiveRecord::Migration[5.0]
  def up
    add_column :users, :role, :string, default: 'user'
  end

  def down
    remove_column :users, :role
  end
end

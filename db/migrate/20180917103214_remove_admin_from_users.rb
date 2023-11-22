# frozen_string_literal: true

class RemoveAdminFromUsers < ActiveRecord::Migration[5.1]
  def up
    remove_column :users, :admin
  end

  def down
    add_column :users, :admin, :boolean, default: false, null: false
  end
end

# frozen_string_literal: true

class AddFamilyNameToUsers < ActiveRecord::Migration[5.0]
  def up
    add_column :users, :family_name, :string, null: false, default: ''
    add_column :users, :locked_at, :datetime
    add_column :users, :external, :boolean, null: false, default: true
    rename_column :users, :name, :given_name
  end

  def down
    remove_column :users, :family_name
    remove_column :users, :locked_at
    remove_column :users, :external
    rename_column :users, :given_name, :name
  end
end

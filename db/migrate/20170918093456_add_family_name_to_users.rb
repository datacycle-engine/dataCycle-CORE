class AddFamilyNameToUsers < ActiveRecord::Migration[5.0]
  def up
    add_column :users, :family_name, :string, null: false, default: ""
    rename_column :users, :name, :given_name
  end

  def down
    remove_column :users, :family_name
    rename_column :users, :given_name, :name
  end
end

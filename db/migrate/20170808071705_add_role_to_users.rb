class AddRoleToUsers < ActiveRecord::Migration[5.0]
  def up
    add_column :users, :role, :string
  end

  def down
    remove_column :users, :role
  end
end

# frozen_string_literal: true

class CreateRoles < ActiveRecord::Migration[5.0]
  # rubocop:disable Rails/BulkChangeTable
  def up
    create_table :roles, id: :uuid do |t|
      t.string :name
      t.integer :rank
      t.timestamps
      t.index :name
      t.index :rank
    end
    remove_column :users, :role
    add_column :users, :role_id, :uuid
  end

  def down
    drop_table :roles
    add_column :users, :role, :string, default: 'user'
    remove_column :users, :role_id
  end
  # rubocop:enable Rails/BulkChangeTable
end

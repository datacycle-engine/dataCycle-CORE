# frozen_string_literal: true

class AddTypeToUsers < ActiveRecord::Migration[5.0]
  # rubocop:disable Rails/BulkChangeTable
  def up
    add_column :users, :type, :string
    add_column :users, :name, :string
  end

  def down
    remove_column :users, :type
  end
  # rubocop:enable Rails/BulkChangeTable
end

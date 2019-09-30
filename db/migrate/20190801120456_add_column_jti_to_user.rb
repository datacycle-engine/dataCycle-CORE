# frozen_string_literal: true

class AddColumnJtiToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :jti, :string
    add_reference :users, :creator, type: :uuid, index: true
    add_index :users, :jti, unique: true
  end
end

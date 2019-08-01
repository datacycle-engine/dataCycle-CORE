# frozen_string_literal: true

class AddColumnJtiToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :jti, :string
    DataCycleCore::User.all.find_each { |user| user.update_column(:jti, SecureRandom.uuid) }
    change_column_null :users, :jti, false
    add_index :users, :jti, unique: true
  end
end

# frozen_string_literal: true

class AddDeviseFailedAttemptsToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :failed_attempts, :integer, default: 0, null: false, if_not_exists: true
  end

  def down
    remove_column :users, :failed_attempts, if_exists: true
  end
end

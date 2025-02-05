# frozen_string_literal: true

class AddDeviseConfirmableToUsers < ActiveRecord::Migration[5.2]
  # rubocop:disable Rails/BulkChangeTable
  def up
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    execute 'UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL'
  end
  # rubocop:enable Rails/BulkChangeTable
end

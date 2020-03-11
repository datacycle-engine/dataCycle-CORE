# frozen_string_literal: true

class AddDeviseConfirmableToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    DataCycleCore::User.connection.schema_cache.clear!
    DataCycleCore::User.reset_column_information
    DataCycleCore::User.update_all(confirmed_at: Time.zone.now - 1.day)
  end
end

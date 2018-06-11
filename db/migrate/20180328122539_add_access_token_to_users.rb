# frozen_string_literal: true

class AddAccessTokenToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :access_token, :string
  end
end

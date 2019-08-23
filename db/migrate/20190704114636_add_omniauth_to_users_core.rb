# frozen_string_literal: true

class AddOmniauthToUsersCore < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :provider, :string unless column_exists? :users, :provider
    add_column :users, :uid, :string unless column_exists? :users, :uid
  end
end

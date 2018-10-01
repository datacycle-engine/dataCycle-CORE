# frozen_string_literal: true

class AddPersonColumnsToThings < ActiveRecord::Migration[5.1]
  def change
    add_column :things, :given_name, :string
    add_column :things, :family_name, :string
    add_column :thing_histories, :given_name, :string
    add_column :thing_histories, :family_name, :string
  end
end

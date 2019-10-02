# frozen_string_literal: true

class AddAdditionalAttributesToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :additional_attributes, :jsonb
  end
end

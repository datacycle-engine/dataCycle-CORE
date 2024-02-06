# frozen_string_literal: true

class AddSelfContaindedToSearch < ActiveRecord::Migration[6.1]
  def change
    add_column :searches, :self_contained, :boolean, default: true, null: false
  end
end

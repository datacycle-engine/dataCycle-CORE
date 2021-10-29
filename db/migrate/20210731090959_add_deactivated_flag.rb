# frozen_string_literal: true

class AddDeactivatedFlag < ActiveRecord::Migration[5.2]
  def change
    add_column :external_systems, :deactivated, :boolean, default: false
  end
end

# frozen_string_literal: true

class AddStatusToThingExternalSystems < ActiveRecord::Migration[5.1]
  def change
    add_column :thing_external_systems, :status, :string
  end
end

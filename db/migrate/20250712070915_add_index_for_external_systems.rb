# frozen_string_literal: true

class AddIndexForExternalSystems < ActiveRecord::Migration[7.1]
  def change
    add_index :external_systems, :config, using: :gin
  end
end

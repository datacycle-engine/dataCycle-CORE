# frozen_string_literal: true

class AddIdentifierToExternalSourceAndSystem < ActiveRecord::Migration[5.2]
  def change
    add_column :external_sources, :identifier, :string
    add_column :external_systems, :identifier, :string
  end
end

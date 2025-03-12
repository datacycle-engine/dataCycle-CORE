# frozen_string_literal: true

class AddModuleBaseForExternalSystems < ActiveRecord::Migration[7.1]
  def change
    add_column :external_systems, :module_base, :string
  end
end

# frozen_string_literal: true

class AddForeignKeysForExternalSystems < ActiveRecord::Migration[6.1]
  def change
    add_foreign_key :external_system_syncs, :external_systems, on_delete: :cascade, validate: false
    add_foreign_key :things, :external_systems, column: :external_source_id, on_delete: :nullify, validate: false
    add_foreign_key :thing_histories, :external_systems, column: :external_source_id, on_delete: :nullify, validate: false
  end
end

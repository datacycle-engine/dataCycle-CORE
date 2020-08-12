# frozen_string_literal: true

class AddCollumnExternalKeyToExternalSystemSyncs < ActiveRecord::Migration[5.2]
  def up
    remove_index :external_system_syncs, name: :index_external_system_syncs_on_syncable_external_system
    add_column :external_system_syncs, :external_key, :string
    add_index :external_system_syncs, [:syncable_type, :syncable_id, :external_system_id, :external_key], name: :index_external_system_syncs_on_syncable_external_system_keys, unique: true
  end

  def down
    remove_index :index_external_system_syncs_on_syncable_external_system_keys
    remove_column :external_system_syncs, :external_key, :string
    add_index :external_system_syncs, [:syncable_type, :syncable_id, :external_system_id], name: :index_external_system_syncs_on_syncable_external_system, unique: true
  end
end

# frozen_string_literal: true

class ChangeThingExternalSystemsToPolymorphic < ActiveRecord::Migration[5.1]
  def up
    remove_index :thing_external_systems, [:thing_id, :external_system_id]
    rename_table :thing_external_systems, :external_system_syncs
    rename_column :external_system_syncs, :thing_id, :syncable_id
    add_column :external_system_syncs, :syncable_type, :string, default: 'DataCycleCore::Thing'
    add_index :external_system_syncs, [:syncable_type, :syncable_id, :external_system_id], name: :index_external_system_syncs_on_syncable_external_system, unique: true
  end

  def down
    remove_index :external_system_syncs, name: :index_external_system_syncs_on_syncable_external_system
    rename_table :external_system_syncs, :thing_external_systems
    rename_column :thing_external_systems, :syncable_id, :thing_id
    add_index :thing_external_systems, [:thing_id, :external_system_id], unique: true
    remove_column :thing_external_systems, :syncable_type
  end
end

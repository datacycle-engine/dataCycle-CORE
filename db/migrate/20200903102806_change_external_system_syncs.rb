# frozen_string_literal: true

class ChangeExternalSystemSyncs < ActiveRecord::Migration[5.2]
  # rubocop:disable Rails/BulkChangeTable
  def change
    rename_column :external_system_syncs, :last_push_at, :last_sync_at
    rename_column :external_system_syncs, :last_successful_push_at, :last_successful_sync_at

    remove_column :external_system_syncs, :last_pull_at, :datetime
    remove_column :external_system_syncs, :last_successful_pull_at, :datetime

    add_column :external_system_syncs, :sync_type, :string, default: 'export'

    remove_index :external_system_syncs, column: [:syncable_type, :syncable_id, :external_system_id, :external_key], name: :index_external_system_syncs_on_syncable_external_system_keys, unique: true

    add_index :external_system_syncs, [:syncable_type, :syncable_id, :external_system_id, :sync_type, :external_key], name: :index_external_system_syncs_on_unique_attributes, unique: true
  end
  # rubocop:enable Rails/BulkChangeTable
end

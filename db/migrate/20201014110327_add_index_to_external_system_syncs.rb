# frozen_string_literal: true

class AddIndexToExternalSystemSyncs < ActiveRecord::Migration[5.2]
  def up
    add_index :external_system_syncs, [:external_system_id, :external_key, :sync_type], name: 'by_external_connection_and_type' unless index_name_exists?(:external_system_syncs, 'by_external_connection_and_type')
  end

  def down
    remove_index :external_system_syncs, name: 'by_external_connection_and_type' if index_name_exists?(:external_system_syncs, 'by_external_connection_and_type')
  end
end

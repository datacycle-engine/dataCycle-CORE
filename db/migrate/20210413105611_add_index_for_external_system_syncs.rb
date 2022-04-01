# frozen_string_literal: true

class AddIndexForExternalSystemSyncs < ActiveRecord::Migration[5.2]
  def up
    add_index :external_system_syncs, [:external_system_id, :syncable_id], name: 'by_external_system_id_syncable_id' unless index_name_exists?(:external_system_syncs, 'by_external_system_id_syncable_id')
  end

  def down
    remove_index :external_system_syncs, name: 'by_external_system_id_syncable_id' if index_name_exists?(:external_system_syncs, 'by_external_system_id_syncable_id')
  end
end

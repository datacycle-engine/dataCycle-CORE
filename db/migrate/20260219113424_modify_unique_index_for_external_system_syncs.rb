# frozen_string_literal: true

class ModifyUniqueIndexForExternalSystemSyncs < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE external_systems
        SET identifier = name
        WHERE identifier IS NULL;
    SQL

    change_table :external_systems, bulk: true do |t|
      t.change_null :identifier, false
      t.change_null :name, false
    end

    execute <<~SQL.squish
      UPDATE external_system_syncs
        SET sync_type = 'duplicate'
        WHERE sync_type IS NULL;
    SQL

    change_table :external_system_syncs, bulk: true do |t|
      t.change_null :syncable_id, false
      t.change_null :syncable_type, false
      t.change_null :external_system_id, false
      t.change_null :sync_type, false
      t.change_default :sync_type, 'duplicate'
    end
  end

  def down
    change_table :external_system_syncs, bulk: true do |t|
      t.change_null :syncable_id, true
      t.change_null :syncable_type, true
      t.change_null :external_system_id, true
      t.change_null :sync_type, true
      t.remove_default :sync_type
    end

    change_table :external_systems, bulk: true do |t|
      t.change_null :identifier, true
      t.change_null :name, true
    end
  end
end

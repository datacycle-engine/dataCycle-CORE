# frozen_string_literal: true

class AddFieldsToExternalSystemSyncs < ActiveRecord::Migration[5.2]
  # rubocop:disable Rails/BulkChangeTable
  def up
    add_column :external_system_syncs, :last_push_at, :datetime
    add_column :external_system_syncs, :last_successful_push_at, :datetime

    execute <<-SQL
      UPDATE external_system_syncs
      SET last_successful_push_at = ((external_system_syncs.data ->> 'last_success_at')::timestamp with time zone)::timestamp
      WHERE external_system_syncs.data ->> 'last_success_at' IS NOT NULL
    SQL
  end

  def down
    remove_column :external_system_syncs, :last_push_at
    remove_column :external_system_syncs, :last_successful_push_at
  end
  # rubocop:enable Rails/BulkChangeTable
end

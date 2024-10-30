# frozen_string_literal: true

class AddPullAttributesExternalSystemSyncs < ActiveRecord::Migration[5.2]
  # rubocop:disable Rails/BulkChangeTable
  def change
    add_column :external_system_syncs, :last_pull_at, :datetime
    add_column :external_system_syncs, :last_successful_pull_at, :datetime
  end
  # rubocop:enable Rails/BulkChangeTable
end

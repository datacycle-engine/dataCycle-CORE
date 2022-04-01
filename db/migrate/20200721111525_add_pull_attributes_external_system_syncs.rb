# frozen_string_literal: true

class AddPullAttributesExternalSystemSyncs < ActiveRecord::Migration[5.2]
  def change
    add_column :external_system_syncs, :last_pull_at, :datetime
    add_column :external_system_syncs, :last_successful_pull_at, :datetime
  end
end

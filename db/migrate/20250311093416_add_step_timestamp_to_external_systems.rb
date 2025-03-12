class AddStepTimestampToExternalSystems < ActiveRecord::Migration[7.1]
  def change
    add_column :external_systems, :last_import_step_time_info, :jsonb, default: {}, null: false
  end
end

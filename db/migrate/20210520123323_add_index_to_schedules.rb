# frozen_string_literal: true

class AddIndexToSchedules < ActiveRecord::Migration[5.2]
  def up
    add_index :schedules, [:external_source_id, :external_key], name: 'by_external_source_id_external_key' unless index_name_exists?(:schedules, 'by_external_source_id_external_key')
  end

  def down
    remove_index :schedules, name: 'by_external_source_id_external_key' if index_name_exists?(:schedules, 'by_external_source_id_external_key')
  end
end

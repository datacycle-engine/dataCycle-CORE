# frozen_string_literal: true

class AddDurationsToExternalSystem < ActiveRecord::Migration[6.1]
  def up
    add_column :external_systems, :last_successful_download_time, :interval
    add_column :external_systems, :last_download_time, :interval
    add_column :external_systems, :last_successful_import_time, :interval
    add_column :external_systems, :last_import_time, :interval
  end

  def down
    remove_column :external_systems, :last_import_time
    remove_column :external_systems, :last_successful_import_time
    remove_column :external_systems, :last_download_time
    remove_column :external_systems, :last_successful_download_time
  end
end

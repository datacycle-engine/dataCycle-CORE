# frozen_string_literal: true

class MigrateMetaDataToExifTool < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(queue: 'default').perform_later('dc:assets:images:update_meta_data')
  end

  def down
  end
end

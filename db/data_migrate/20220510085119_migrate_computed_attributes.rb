# frozen_string_literal: true

class MigrateComputedAttributes < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(queue: 'default').perform_later('dc:update_data:computed_attributes', [nil, false, 'copyright_notice_computed'])
  end

  def down
  end
end

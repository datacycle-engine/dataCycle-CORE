# frozen_string_literal: true

class UpdateFileFormatComputedAfterBugfix < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(queue: 'default').perform_later('dc:update_data:computed_attributes', [nil, true, 'file_format'])
  end

  def down
  end
end

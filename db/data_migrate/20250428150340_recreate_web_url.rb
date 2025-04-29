# frozen_string_literal: true

class RecreateWebUrl < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:update_data:computed_attributes', [nil, false, 'web_url'])
  end

  def down
  end
end

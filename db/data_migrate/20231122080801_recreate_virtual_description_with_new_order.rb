# frozen_string_literal: true

class RecreateVirtualDescriptionWithNewOrder < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:update_data:computed_attributes', [nil, false, 'virtual_description'])
  end

  def down
  end
end

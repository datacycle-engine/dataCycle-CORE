# frozen_string_literal: true

class FixRebuildingTransitiveTables < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::Feature::TransitiveClassificationPath.update_triggers
  end

  def down
  end
end

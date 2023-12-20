# frozen_string_literal: true

class RebuildTransitiveTablesAfterFixForTriggerFunction < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::Feature::TransitiveClassificationPath.update_triggers if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
  end

  def down
  end
end

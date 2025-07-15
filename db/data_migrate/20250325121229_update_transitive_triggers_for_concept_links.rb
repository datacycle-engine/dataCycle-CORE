# frozen_string_literal: true

class UpdateTransitiveTriggersForConceptLinks < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
  end

  def down
  end
end

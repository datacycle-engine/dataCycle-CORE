# frozen_string_literal: true

class RebuildCccWithoutTransitive < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::Feature::TransitiveClassificationPath.update_triggers unless DataCycleCore::Feature::TransitiveClassificationPath.enabled?
  end

  def down
  end
end

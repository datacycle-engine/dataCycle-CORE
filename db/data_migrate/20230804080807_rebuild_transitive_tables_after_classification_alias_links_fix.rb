# frozen_string_literal: true

class RebuildTransitiveTablesAfterClassificationAliasLinksFix < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('db:configure:rebuild_transitive_tables') if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
  end

  def down
  end
end

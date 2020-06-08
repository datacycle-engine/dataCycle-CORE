# frozen_string_literal: true

class AddIdentifierToExternalSourceAndSystem < ActiveRecord::Migration[5.2]
  def change
    add_column :external_sources, :identifier, :string
    add_column :external_systems, :identifier, :string

    # DataCycleCore::ExternalSource.connection.schema_cache.clear!
    # DataCycleCore::ExternalSource.reset_column_information
    DataCycleCore::ExternalSystem.connection.schema_cache.clear!
    DataCycleCore::ExternalSystem.reset_column_information
  end
end

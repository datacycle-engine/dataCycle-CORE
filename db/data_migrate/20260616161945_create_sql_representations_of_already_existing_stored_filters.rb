# frozen_string_literal: true

class CreateSqlRepresentationsOfAlreadyExistingStoredFilters < ActiveRecord::Migration[8.0]
  # Builds the SQL representation for every named stored filter. Self-referential filters (which have
  # no finite representation) are removed by the preceding DeleteSelfReferentialStoredFilters migration
  # and rejected on save, so none are encountered here.
  def up
    DataCycleCore::StoredFilter.where.not(name: nil).find_each(&:sync_sql_representation!)
  end

  def down
    DataCycleCore::StoredFilter.where.not(name: nil).find_each(&:drop_sql_representation!)
  end
end

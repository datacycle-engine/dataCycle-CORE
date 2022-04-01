# frozen_string_literal: true

class AddSortParametersToStoredFilters < ActiveRecord::Migration[5.2]
  def change
    add_column :stored_filters, :sort_parameters, :jsonb
    add_index :things, [:boost, :updated_at, :id], name: 'index_things_on_boost_updated_at_id'
  end
end

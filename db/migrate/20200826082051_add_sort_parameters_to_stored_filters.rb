# frozen_string_literal: true

class AddSortParametersToStoredFilters < ActiveRecord::Migration[5.2]
  def change
    add_column :stored_filters, :sort_parameters, :jsonb
  end
end

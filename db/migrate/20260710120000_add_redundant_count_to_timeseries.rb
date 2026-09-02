# frozen_string_literal: true

# Redmine #39891: redundant_count tracks how many raw datapoints a collapsed row represents.
class AddRedundantCountToTimeseries < ActiveRecord::Migration[8.0]
  def up
    add_column :timeseries, :redundant_count, :integer, default: 1, null: false, if_not_exists: true
  end

  def down
    remove_column :timeseries, :redundant_count, if_exists: true
  end
end

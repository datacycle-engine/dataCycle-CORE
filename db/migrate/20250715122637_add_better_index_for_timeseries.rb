# frozen_string_literal: true

class AddBetterIndexForTimeseries < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;
    SQL

    change_table :timeseries, bulk: true do |t|
      t.remove_index name: 'thing_attribute_timestamp_idx'
      t.index [:thing_id, :property, :timestamp], name: 'thing_attribute_timestamp_idx', unique: true, include: :value
    end
  end

  def down
  end
end

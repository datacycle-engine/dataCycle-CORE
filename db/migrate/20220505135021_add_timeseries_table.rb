# frozen_string_literal: true

class AddTimeseriesTable < ActiveRecord::Migration[6.1]
  def change
    create_table :timeseries, id: false do |t|
      t.uuid      :thing_id, null: false                                        # thing_id
      t.string    :property, null: false                                        # attribute_name
      t.column    :timestamp, 'timestamp with time zone', null: false           # start_date_time
      t.float     :value                                                        # stored value
      t.timestamps
    end
    add_foreign_key :timeseries, :things, on_delete: :cascade
    add_index :timeseries, [:thing_id, :property, :timestamp], name: 'thing_attribute_timestamp_idx', unique: true
  end
end

# frozen_string_literal: true

class AddScheduleRrule < ActiveRecord::Migration[5.2]
  def change
    # https://github.com/petropavel13/pg_rrule
    enable_extension 'pg_rrule' unless extension_enabled?('pg_rrule')

    create_table :schedules, id: :uuid do |t|
      t.uuid :thing_id
      t.string :relation
      t.column :dtstart, 'timestamp with time zone'
      t.column :dtend, 'timestamp with time zone'
      t.interval :duration
      t.string :rrule
      t.column :rdate, 'timestamp with time zone', array: true, default: []
      t.column :exdate, 'timestamp with time zone', array: true, default: []
      t.uuid :external_source_id
      t.string :external_key
      t.datetime :seen_at
      t.timestamps
    end
  end
end

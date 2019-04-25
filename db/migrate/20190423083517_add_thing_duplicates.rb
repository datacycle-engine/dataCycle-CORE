# frozen_string_literal: true

class AddThingDuplicates < ActiveRecord::Migration[5.1]
  def change
    create_table :thing_duplicates, id: :uuid do |t|
      t.uuid     :thing_id
      t.uuid     :thing_duplicate_id
      t.string   :method
      t.float    :score
      t.boolean  :false_positive, default: false, null: false
      t.timestamps
      t.index ['thing_id', 'thing_duplicate_id', 'method'], name: 'unique_duplicate_index', unique: true
    end
  end
end

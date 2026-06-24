# frozen_string_literal: true

class AdjustColumnsAndIndexForThingDuplicates < ActiveRecord::Migration[7.1]
  def up
    execute 'SET LOCAL statement_timeout = 0;'

    change_table :thing_duplicates, bulk: true do |t|
      t.remove_index name: 'unique_thing_duplicate_idx'
      t.remove_index name: 'unique_duplicate_index'
      t.remove :thing_ids
      t.virtual :thing_ids, type: :uuid, as: 'ARRAY[LEAST(thing_id, thing_duplicate_id), GREATEST(thing_id, thing_duplicate_id)]', array: true, stored: true
      t.index :thing_ids, name: 'unique_thing_duplicate_idx', unique: true, using: :btree
      t.index :thing_ids, name: 'index_thing_duplicates_on_thing_ids', using: :gin
      t.index [:thing_id, :thing_duplicate_id, :method], name: 'thing_duplicate_idx', using: :btree
    end
  end

  def down
    execute 'SET LOCAL statement_timeout = 0;'

    change_table :thing_duplicates, bulk: true do |t|
      t.remove_index name: 'unique_thing_duplicate_idx'
      t.remove_index name: 'thing_duplicate_idx'
      t.remove :thing_ids
      t.virtual :thing_ids, type: :uuid, as: 'ARRAY[thing_id, thing_duplicate_id]', array: true, stored: true
      t.index [:thing_id, :thing_duplicate_id, :method], name: 'unique_duplicate_index', unique: true, using: :btree
      t.index 'LEAST(thing_id, thing_duplicate_id), GREATEST(thing_id, thing_duplicate_id)', name: 'unique_thing_duplicate_idx', unique: true, using: :btree
      t.index :thing_ids, name: 'index_thing_duplicates_on_thing_ids', using: :gin
    end
  end
end

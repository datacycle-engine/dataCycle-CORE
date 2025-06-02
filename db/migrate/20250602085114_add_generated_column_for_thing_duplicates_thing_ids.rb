# frozen_string_literal: true

class AddGeneratedColumnForThingDuplicatesThingIds < ActiveRecord::Migration[7.1]
  def up
    execute 'SET LOCAL statement_timeout = 0;'
    add_column :thing_duplicates, :thing_ids, :virtual, type: :uuid, as: 'ARRAY[thing_id, thing_duplicate_id]', array: true, stored: true
    add_index :thing_duplicates, :thing_ids, using: :gin, name: 'index_thing_duplicates_on_thing_ids'
  end

  def down
    execute 'SET LOCAL statement_timeout = 0;'
    remove_index :thing_duplicates, name: 'index_thing_duplicates_on_thing_ids'
    remove_column :thing_duplicates, :thing_ids
  end
end

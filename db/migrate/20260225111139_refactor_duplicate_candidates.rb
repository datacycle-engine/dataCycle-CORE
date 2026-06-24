# frozen_string_literal: true

class RefactorDuplicateCandidates < ActiveRecord::Migration[8.0]
  def up
    change_table :thing_duplicates, bulk: true do |t|
      t.remove_index name: 'unique_thing_duplicate_idx'
      t.index [:thing_ids, :method], name: 'unique_thing_duplicate_idx', unique: true, using: :btree
    end
  end

  def down
    change_table :thing_duplicates, bulk: true do |t|
      t.remove_index name: 'unique_thing_duplicate_idx'
      t.index :thing_ids, name: 'unique_thing_duplicate_idx', unique: true, using: :btree
    end
  end
end

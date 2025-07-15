# frozen_string_literal: true

class AddIndexForThingDuplicatesDuplicateId < ActiveRecord::Migration[7.1]
  def change
    add_index :thing_duplicates, :thing_duplicate_id
  end
end

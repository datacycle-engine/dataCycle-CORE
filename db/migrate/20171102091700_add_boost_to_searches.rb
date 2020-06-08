# frozen_string_literal: true

class AddBoostToSearches < ActiveRecord::Migration[5.0]
  def up
    add_column :searches, :boost, :float, default: 1.0, null: false
  end

  def down
    remove_column :searches, :boost
  end
end

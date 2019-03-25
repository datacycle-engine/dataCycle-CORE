# frozen_string_literal: true

class RenameSeenAtToTouchedAtForThings < ActiveRecord::Migration[5.1]
  def change
    rename_column :things, :seen_at, :touched_at
    rename_column :thing_histories, :seen_at, :touched_at
  end
end

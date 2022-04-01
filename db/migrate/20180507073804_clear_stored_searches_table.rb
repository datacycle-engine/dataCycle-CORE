# frozen_string_literal: true

class ClearStoredSearchesTable < ActiveRecord::Migration[5.0]
  def up
    execute <<-SQL
      TRUNCATE TABLE stored_filters;
    SQL
  end

  def down
  end
end

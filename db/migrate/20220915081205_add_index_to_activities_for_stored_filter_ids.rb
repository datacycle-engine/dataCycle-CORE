# frozen_string_literal: true

class AddIndexToActivitiesForStoredFilterIds < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE INDEX IF NOT EXISTS
        activities_data_id_idx ON activities ((DATA ->> 'id'));
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP INDEX IF EXISTS
        activities_data_id_idx;
    SQL
  end
end

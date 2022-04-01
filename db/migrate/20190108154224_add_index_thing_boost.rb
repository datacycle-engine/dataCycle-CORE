# frozen_string_literal: true

class AddIndexThingBoost < ActiveRecord::Migration[5.1]
  def up
    add_column :things, :validity_range, :tstzrange
    add_column :thing_histories, :validity_range, :tstzrange # needs a migration task
    execute <<-SQL
      UPDATE things as tt SET
        validity_range = searches.validity_period
      FROM searches
      where tt.id = searches.content_data_id
    SQL

    add_column :things, :boost, :numeric
    add_column :thing_histories, :boost, :numeric
    execute <<-SQL
      UPDATE things SET boost = (schema ->> 'boost')::NUMERIC;
      UPDATE thing_histories SET boost = (schema ->> 'boost')::NUMERIC;
    SQL
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_things_on_boost ON things (boost DESC NULLS LAST);
      CREATE INDEX IF NOT EXISTS index_validity_range ON things USING GIST (validity_range);
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX IF EXISTS index_things_on_boost;
      DROP INDEX IF EXISTS index_validity_range;
    SQL
    remove_column :things, :boost
    remove_column :thing_histories, :boost
    remove_column :things, :validity_range
    remove_column :thing_histories, :validity_range
  end
end

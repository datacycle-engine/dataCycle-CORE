# frozen_string_literal: true

class AddSpatialIndexesOnLines < ActiveRecord::Migration[5.2]
  def up
    add_index :things, :line, name: 'index_things_on_line_spatial', using: 'gist'

    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_things_on_line_geography_cast ON things USING GIST (geography(line));
    SQL
  end

  def down
    remove_index :things, name: 'index_things_on_line_spatial'

    execute <<-SQL
      DROP INDEX IF EXISTS index_things_on_line_geography_cast;
    SQL
  end
end

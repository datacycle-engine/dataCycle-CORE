# frozen_string_literal: true

class AddGeographyIndexforLocation < ActiveRecord::Migration[5.2]
  # def change
  #   add_index :things, :location, name: 'index_things_on_location_geography_cast', using: 'gist'
  #   CREATE INDEX index_things_on_location_geography_cast ON things USING GIST (geography(location));
  # end
  def up
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_things_on_location_geography_cast ON things USING GIST (geography(location));
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX IF EXISTS index_things_on_location_geography_cast;
    SQL
  end
end

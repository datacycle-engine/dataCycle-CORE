# frozen_string_literal: true

class FixStoredGeoFilters < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      UPDATE stored_filters
      SET parameters = REPLACE( parameters::TEXT, '"n": "geo_radius", "t": "geo_radius"'::TEXT, '"n": "geo_radius", "t": "geo_filter", "q": "geo_radius", "m": "i"'::TEXT )::JSONB
      WHERE parameters::TEXT ILIKE '%"n": "geo_radius", "t": "geo_radius"%'
    SQL
  end

  def down
  end
end

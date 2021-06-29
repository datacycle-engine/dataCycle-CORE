# frozen_string_literal: true

class FixStoredGeoWithinClassificationFilters < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      UPDATE stored_filters
      SET parameters = REPLACE( parameters::TEXT, '"n": "Administrative Einheiten", "t": "geo_within_classification"'::TEXT, '"n": "Administrative Einheiten", "q": "geo_within_classification", "t": "geo_filter"'::TEXT )::JSONB
      WHERE parameters::TEXT ILIKE '%"n": "Administrative Einheiten", "t": "geo_within_classification"%'
    SQL
  end

  def down
  end
end

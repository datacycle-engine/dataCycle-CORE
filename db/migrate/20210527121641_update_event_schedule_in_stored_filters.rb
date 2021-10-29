# frozen_string_literal: true

class UpdateEventScheduleInStoredFilters < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      UPDATE stored_filters
      SET parameters = REPLACE(parameters::TEXT, '"n": "absolute", "q": "absolute", "t": "in_schedule"', '"n": "event_schedule", "q": "absolute", "t": "in_schedule"')::JSONB
      WHERE parameters::TEXT ILIKE '%"n": "absolute", "q": "absolute", "t": "in_schedule"%'
    SQL

    execute <<-SQL.squish
      UPDATE stored_filters
      SET parameters = REPLACE(parameters::TEXT, '"n": "relative", "q": "relative", "t": "in_schedule"', '"n": "event_schedule", "q": "relative", "t": "in_schedule"')::JSONB
      WHERE parameters::TEXT ILIKE '%"n": "relative", "q": "relative", "t": "in_schedule"%'
    SQL

    execute <<-SQL.squish
      UPDATE stored_filters
      SET sort_parameters = REPLACE(sort_parameters::TEXT, '"n": "absolute", "q": "absolute", "t": "in_schedule"', '"n": "event_schedule", "q": "absolute", "t": "in_schedule"')::JSONB
      WHERE sort_parameters::TEXT ILIKE '%"n": "absolute", "q": "absolute", "t": "in_schedule"%'
    SQL

    execute <<-SQL.squish
      UPDATE stored_filters
      SET sort_parameters = REPLACE(sort_parameters::TEXT, '"n": "relative", "q": "relative", "t": "in_schedule"', '"n": "event_schedule", "q": "relative", "t": "in_schedule"')::JSONB
      WHERE sort_parameters::TEXT ILIKE '%"n": "relative", "q": "relative", "t": "in_schedule"%'
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE stored_filters
      SET parameters = REPLACE(parameters::TEXT, '"n": "event_schedule", "q": "absolute", "t": "in_schedule"', '"n": "absolute", "q": "absolute", "t": "in_schedule"')::JSONB
      WHERE parameters::TEXT ILIKE '%"n": "event_schedule", "q": "absolute", "t": "in_schedule"%'
    SQL

    execute <<-SQL.squish
      UPDATE stored_filters
      SET parameters = REPLACE(parameters::TEXT, '"n": "event_schedule", "q": "relative", "t": "in_schedule"', '"n": "relative", "q": "relative", "t": "in_schedule"')::JSONB
      WHERE parameters::TEXT ILIKE '%"n": "event_schedule", "q": "relative", "t": "in_schedule"%'
    SQL

    execute <<-SQL.squish
      UPDATE stored_filters
      SET sort_parameters = REPLACE(sort_parameters::TEXT, '"n": "event_schedule", "q": "absolute", "t": "in_schedule"', '"n": "absolute", "q": "absolute", "t": "in_schedule"')::JSONB
      WHERE sort_parameters::TEXT ILIKE '%"n": "event_schedule", "q": "absolute", "t": "in_schedule"%'
    SQL

    execute <<-SQL.squish
      UPDATE stored_filters
      SET sort_parameters = REPLACE(sort_parameters::TEXT, '"n": "event_schedule", "q": "relative", "t": "in_schedule"', '"n": "relative", "q": "relative", "t": "in_schedule"')::JSONB
      WHERE sort_parameters::TEXT ILIKE '%"n": "event_schedule", "q": "relative", "t": "in_schedule"%'
    SQL
  end
end

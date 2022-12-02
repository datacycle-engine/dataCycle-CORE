# frozen_string_literal: true

class AddDefaultTimestamptToTimeseries < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE timeseries ALTER COLUMN created_at SET DEFAULT transaction_timestamp();
      ALTER TABLE timeseries ALTER COLUMN updated_at SET DEFAULT transaction_timestamp();
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE timeseries ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE timeseries ALTER COLUMN updated_at DROP DEFAULT;
    SQL
  end
end

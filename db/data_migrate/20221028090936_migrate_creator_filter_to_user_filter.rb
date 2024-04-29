# frozen_string_literal: true

class MigrateCreatorFilterToUserFilter < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    return unless ActiveRecord::Base.connection.table_exists? 'stored_filters'
    execute <<-SQL
      UPDATE
        stored_filters
      SET
        parameters = REPLACE(parameters::TEXT, '"n": "Creator", "t": "creator"'::TEXT, '"n": "creator", "q": "creator", "t": "user"'::TEXT)::JSONB
      WHERE
        parameters::TEXT ILIKE '%"n": "Creator", "t": "creator"%';
    SQL
  end

  def down
    return unless ActiveRecord::Base.connection.table_exists? 'stored_filters'
    execute <<-SQL
      UPDATE
        stored_filters
      SET
        parameters = REPLACE(parameters::TEXT, '"n": "creator", "q": "creator", "t": "user"'::TEXT, '"n": "Creator", "t": "creator"'::TEXT)::JSONB
      WHERE
        parameters::TEXT ILIKE '%"n": "creator", "q": "creator", "t": "user"%';
    SQL
  end
end

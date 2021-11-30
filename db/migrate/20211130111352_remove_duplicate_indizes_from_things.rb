# frozen_string_literal: true

class RemoveDuplicateIndizesFromThings < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      DROP INDEX IF EXISTS index_things_on_boost_updated_at;
      DROP INDEX IF EXISTS index_things_on_external_source_id;
      DROP INDEX IF EXISTS index_searches_on_content_data_id;
    SQL
  end

  def down
    execute <<-SQL.squish
      CREATE INDEX IF NOT EXISTS index_things_on_boost_updated_at ON things (boost, updated_at);
      CREATE INDEX IF NOT EXISTS index_things_on_external_source_id ON things (external_source_id);
      CREATE INDEX IF NOT EXISTS index_searches_on_content_data_id ON searches (content_data_id);
    SQL
  end
end

# frozen_string_literal: true

class AddCreativeWorksIndex < ActiveRecord::Migration[5.0]
  def up
    execute <<-SQL
      CREATE INDEX index_creative_works_on_external_key ON creative_works ((metadata ->> 'external_key'), external_source_id)
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX index_creative_works_on_external_key
    SQL
  end
end

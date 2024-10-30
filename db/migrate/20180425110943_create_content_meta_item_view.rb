# frozen_string_literal: true

class CreateContentMetaItemView < ActiveRecord::Migration[5.0]
  def up
    query = 'CREATE VIEW content_meta_items AS ' +
            ['creative_works', 'events', 'persons', 'places', 'organizations'].map { |table|
              <<-SQL
                SELECT
                  id,
                  'DataCycleCore::#{table.singularize.classify}' AS "content_type",
                  template_name,
                  "schema",
                  external_source_id,
                  external_key
                FROM #{table}
                WHERE "template" IS FALSE
              SQL
            }.join(' UNION ')

    execute(query)
  end

  def down
    execute('DROP VIEW content_meta_items')
  end
end

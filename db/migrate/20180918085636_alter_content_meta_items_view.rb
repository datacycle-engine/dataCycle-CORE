# frozen_string_literal: true

class AlterContentMetaItemsView < ActiveRecord::Migration[5.1]
  def up
    ActiveRecord::Base.connection.exec_query('DROP VIEW IF EXISTS content_meta_items')

    sql = 'CREATE VIEW content_meta_items AS ' +
          ['creative_works', 'events', 'persons', 'places', 'organizations'].map { |table|
            <<-SQL
              SELECT
                id,
                'DataCycleCore::#{table.singularize.classify}' AS "content_type",
                template_name,
                "schema",
                external_source_id,
                external_key,
                created_by,
                updated_by,
                deleted_by
              FROM #{table}
              WHERE "template" IS FALSE
            SQL
          }.join(' UNION ')

    ActiveRecord::Base.connection.exec_query(sql)
  end

  def down
    ActiveRecord::Base.connection.exec_query('DROP VIEW IF EXISTS content_meta_items')

    sql = 'CREATE VIEW content_meta_items AS ' +
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

    ActiveRecord::Base.connection.exec_query(sql)
  end
end

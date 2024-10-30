# frozen_string_literal: true

class AddStartEndDateToThings < ActiveRecord::Migration[5.1]
  # rubocop:disable Rails/BulkChangeTable
  def change
    add_column :things, :start_date, :datetime
    add_column :things, :end_date, :datetime
    add_column :thing_histories, :start_date, :datetime
    add_column :thing_histories, :end_date, :datetime

    reversible do |dir|
      dir.up do
        execute('DROP VIEW IF EXISTS content_meta_items')

        sql = 'CREATE VIEW content_meta_items AS ' +
              ['creative_works', 'places', 'things'].map { |table|
                <<-SQL
                  SELECT
                    id,
                    'DataCycleCore::#{table.singularize.classify}' AS content_type,
                    template_name,
                    schema,
                    external_source_id,
                    external_key,
                    created_by,
                    updated_by,
                    deleted_by
                  FROM #{table}
                  WHERE template IS FALSE
                SQL
              }.join(' UNION ')
        execute(sql)
      end

      dir.down do
        execute('DROP VIEW IF EXISTS content_meta_items')

        sql = 'CREATE VIEW content_meta_items AS ' +
              ['creative_works', 'events', 'places', 'things'].map { |table|
                <<-SQL
                  SELECT
                  id,
                  'DataCycleCore::#{table.singularize.classify}' AS content_type,
                  template_name,
                  schema,
                  external_source_id,
                  external_key,
                  created_by,
                  updated_by,
                  deleted_by
                FROM #{table}
                WHERE template IS FALSE
                SQL
              }.join(' UNION ')
        execute(sql)
      end
    end
  end
  # rubocop:enable Rails/BulkChangeTable
end

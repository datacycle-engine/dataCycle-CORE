# frozen_string_literal: true

class AddCreativeWorkAttributesToThings < ActiveRecord::Migration[5.1]
  def change
    add_column :things, :is_part_of, :uuid
    add_column :thing_histories, :is_part_of, :uuid

    reversible do |dir|
      dir.up do
        execute('DROP VIEW IF EXISTS content_meta_items')

        sql = <<-SQL
          CREATE VIEW content_meta_items AS
            SELECT
              id,
              'DataCycleCore::Thing' AS content_type,
              template_name,
              schema,
              external_source_id,
              external_key,
              created_by,
              updated_by,
              deleted_by
            FROM things
            WHERE template IS FALSE
        SQL
        execute(sql)
      end

      dir.down do
        execute('DROP VIEW IF EXISTS content_meta_items')

        sql = 'CREATE VIEW content_meta_items AS '
        sql += ['creative_works', 'things'].map { |table|
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
end

# frozen_string_literal: true

class AddPersonColumnsToThings < ActiveRecord::Migration[5.1]
  def change
    add_column :things, :given_name, :string
    add_column :things, :family_name, :string
    add_column :thing_histories, :given_name, :string
    add_column :thing_histories, :family_name, :string

    reversible do |dir|
      dir.up do
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

      dir.down do
        execute('DROP VIEW IF EXISTS content_meta_items')

        sql = 'CREATE VIEW content_meta_items AS ' +
              ['creative_works', 'events', 'persons', 'places', 'things'].map { |table|
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

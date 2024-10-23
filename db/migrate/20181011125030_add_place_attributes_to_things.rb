# frozen_string_literal: true

class AddPlaceAttributesToThings < ActiveRecord::Migration[5.1]
  def change
    add_column :things, :longitude, :float
    add_column :things, :latitude, :float
    add_column :things, :elevation, :float
    add_column :things, :location, :geometry, limit: { srid: 4326, type: 'point' }
    add_column :things, :line, :geometry, limit: { srid: 4326, geographic: true, type: 'line_string', has_z: true }
    add_column :things, :address_locality, :string
    add_column :things, :street_address, :string
    add_column :things, :postal_code, :string
    add_column :things, :address_country, :string
    add_column :things, :fax_number, :string
    add_column :things, :telephone, :string
    add_column :things, :email, :string

    add_column :thing_histories, :longitude, :float
    add_column :thing_histories, :latitude, :float
    add_column :thing_histories, :elevation, :float
    add_column :thing_histories, :location, :geometry, limit: { srid: 4326, type: 'point' }
    add_column :thing_histories, :line, :geometry, limit: { srid: 4326, geographic: true, type: 'line_string', has_z: true }
    # :line, :line_string, geographic: true, srid: 4326, has_z: true
    add_column :thing_histories, :address_locality, :string
    add_column :thing_histories, :street_address, :string
    add_column :thing_histories, :postal_code, :string
    add_column :thing_histories, :address_country, :string
    add_column :thing_histories, :fax_number, :string
    add_column :thing_histories, :telephone, :string
    add_column :thing_histories, :email, :string

    reversible do |dir|
      dir.up do
        execute('DROP VIEW IF EXISTS content_meta_items')

        sql = 'CREATE VIEW content_meta_items AS ' +
              ['creative_works', 'things'].map { |table|
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
    end
  end
end

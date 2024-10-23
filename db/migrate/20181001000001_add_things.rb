# frozen_string_literal: true

class AddThings < ActiveRecord::Migration[5.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    create_table :things, id: :uuid, primary_key: 'id' do |t|
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.string :internal_name
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index [:template, :template_name], name: 'index_things_template_template_name_idx', using: :btree
      t.index :external_source_id, name: 'index_things_on_external_source_id', using: :btree
      t.index [:external_source_id, :external_key], name: 'index_things_on_external_source_id_and_external_key', unique: true, using: :btree
    end

    create_table :thing_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :thing_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :name
      t.text :description
      t.timestamps
      t.index :id, unique: true
      t.index [:thing_id, :locale], name: 'index_thing_id_locale', using: :btree, unique: true
      t.index :thing_id
      t.index :locale
    end

    create_table :thing_histories, id: :uuid, primary_key: 'id' do |t|
      t.uuid :thing_id, null: false
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.string :internal_name
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index :thing_id
    end

    create_table :thing_history_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :thing_history_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :name
      t.text :description
      t.tstzrange :history_valid
      t.timestamps
      t.index :id, unique: true
      t.index [:thing_history_id, :locale], name: 'index_thing_history_id_locale', using: :btree
      t.index :thing_history_id
      t.index :locale
    end

    add_column :searches, :schema_type, :string, null: false, default: 'Thing'
    reversible do |dir|
      dir.up do
        say_with_time 'setting default values for searches.schema_type' do
          ['creative_works', 'events', 'persons', 'places', 'organizations'].each do |table_name|
            table_object_name = "DataCycleCore::#{table_name.classify}"
            excute <<-SQL.squish
              UPDATE searches
              SET schema_type = '#{table_name.classify}'
              WHERE content_data_type = '#{table_object_name}';
            SQL
          end
        end
      end
    end

    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE INDEX IF NOT EXISTS index_things_on_content_type ON things ((schema ->> 'content_type'));
        SQL
      end
      dir.down do
        execute <<-SQL
          DROP INDEX IF EXISTS index_things_on_content_type;
        SQL
      end
    end

    reversible do |dir|
      dir.up do
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

      dir.down do
        execute('DROP VIEW IF EXISTS content_meta_items')

        sql = 'CREATE VIEW content_meta_items AS ' +
              ['creative_works', 'events', 'persons', 'places', 'organizations'].map { |table|
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

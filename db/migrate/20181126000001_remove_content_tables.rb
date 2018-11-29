# frozen_string_literal: true

class RemoveContentTables < ActiveRecord::Migration[5.1]
  def up
    drop_table :organizations, if_exists: true
    drop_table :organization_translations, if_exists: true
    drop_table :organization_histories, if_exists: true
    drop_table :organization_history_translations, if_exists: true

    drop_table :persons, if_exists: true
    drop_table :person_translations, if_exists: true
    drop_table :person_histories, if_exists: true
    drop_table :person_history_translations, if_exists: true

    drop_table :events, if_exists: true
    drop_table :event_translations, if_exists: true
    drop_table :event_histories, if_exists: true
    drop_table :event_history_translations, if_exists: true

    drop_table :places, if_exists: true
    drop_table :place_translations, if_exists: true
    drop_table :place_histories, if_exists: true
    drop_table :place_history_translations, if_exists: true

    drop_table :creative_works, if_exists: true
    drop_table :creative_work_translations, if_exists: true
    drop_table :creative_work_histories, if_exists: true
    drop_table :creative_work_history_translations, if_exists: true
  end

  def down
    create_table :organizations, id: :uuid, primary_key: 'id' do |t|
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index [:template, :template_name], name: 'index_organizations_template_template_name_idx', using: :btree
      t.index :external_source_id, name: 'index_organizations_on_external_source_id', using: :btree
      t.index [:external_source_id, :external_key], name: 'index_organizations_on_external_source_id_and_external_key', unique: true, using: :btree
    end

    create_table :organization_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :organization_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :headline
      t.text :description
      t.timestamps
      t.index :id, unique: true
      t.index [:organization_id, :locale], name: 'index_organizations_id_locale', using: :btree, unique: true
      t.index :organization_id
      t.index :locale
    end

    create_table :organization_histories, id: :uuid, primary_key: 'id' do |t|
      t.uuid :organization_id, null: false
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index :organization_id
    end

    create_table :organization_history_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :organization_history_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :headline
      t.text :description
      t.tstzrange :history_valid
      t.timestamps
      t.index :id, unique: true, name: 'index_organization_history_translation_on_id'
      t.index [:organization_history_id, :locale], name: 'index_organization_history_id_locale', using: :btree
      t.index :organization_history_id, name: 'index_on_organization_history_translation_id'
      t.index :locale, name: 'index_organization_history_translation_on_locale'
    end

    create_table :persons, id: :uuid, primary_key: 'id' do |t|
      t.string :given_name
      t.string :family_name
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index [:template, :template_name], name: 'index_persons_template_template_name_idx', using: :btree
      t.index :external_source_id, name: 'index_persons_on_external_source_id', using: :btree
      t.index [:external_source_id, :external_key], name: 'index_persons_on_external_source_id_and_external_key', unique: true, using: :btree
    end

    create_table :person_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :person_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :headline
      t.text :description
      t.timestamps
      t.index :id, unique: true
      t.index [:person_id, :locale], name: 'index_person_id_locale', using: :btree, unique: true
      t.index :person_id
      t.index :locale
    end

    create_table :person_histories, id: :uuid, primary_key: 'id' do |t|
      t.uuid :person_id
      t.string :given_name
      t.string :family_name
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index :person_id
    end

    create_table :person_history_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :person_history_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :headline
      t.text :description
      t.tstzrange :history_valid
      t.timestamps
      t.index :id, unique: true, name: 'index_person_history_translation_on_id'
      t.index [:person_history_id, :locale], name: 'index_person_history_id_locale', using: :btree
      t.index :person_history_id, name: 'index_on_person_history_translation_id'
      t.index :locale, name: 'index_person_history_translation_on_locale'
    end

    create_table :events, id: :uuid, primary_key: 'id' do |t|
      t.datetime :start_date
      t.datetime :end_date
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index [:template, :template_name], name: 'index_event_template_template_name_idx', using: :btree
      t.index :external_source_id, name: 'index_event_on_external_source_id', using: :btree
      t.index [:external_source_id, :external_key], name: 'index_event_on_external_source_id_and_external_key', unique: true, using: :btree
    end

    create_table :event_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :event_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :headline
      t.text :description
      t.timestamps
      t.index :id, unique: true
      t.index [:event_id, :locale], name: 'index_event_id_locale', using: :btree, unique: true
      t.index :event_id
      t.index :locale
    end

    create_table :event_histories, id: :uuid, primary_key: 'id' do |t|
      t.uuid :event_id
      t.datetime :start_date
      t.datetime :end_date
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index :event_id
    end

    create_table :event_history_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :event_history_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :headline
      t.text :description
      t.tstzrange :history_valid
      t.timestamps
      t.index :id, unique: true, name: 'index_event_history_translation_on_id'
      t.index [:event_history_id, :locale], name: 'index_event_history_id_locale', using: :btree
      t.index :event_history_id, name: 'index_on_event_history_translation_id'
      t.index :locale, name: 'index_event_history_translation_on_locale'
    end

    create_table :places, id: :uuid, primary_key: 'id' do |t|
      t.float :longitude
      t.float :latitude
      t.float :elevation
      t.geometry :location, limit: { srid: 4326, type: 'point' }
      t.line_string :line, geographic: true, srid: 4326, has_z: true
      t.string :address_locality
      t.string :street_address
      t.string :postal_code
      t.string :address_country
      t.string :fax_number
      t.string :telephone
      t.string :email
      t.uuid :photo
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index [:template, :template_name], name: 'index_place_template_template_name_idx', using: :btree
      t.index :external_source_id, name: 'index_place_on_external_source_id', using: :btree
      t.index [:external_source_id, :external_key], name: 'index_place_on_external_source_id_and_external_key', unique: true, using: :btree
    end

    create_table :place_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :place_id, null: false
      t.string :locale, null: false
      t.string :headline
      t.text :description
      t.string :name
      t.string :url
      t.string :hours_available
      t.jsonb :content
      t.timestamps
      t.index :id, unique: true
      t.index [:place_id, :locale], name: 'index_place_id_locale', using: :btree, unique: true
      t.index :place_id
      t.index :locale
    end

    create_table :place_histories, id: :uuid, primary_key: 'id' do |t|
      t.uuid :place_id
      t.float :longitude
      t.float :latitude
      t.float :elevation
      t.geometry :location, limit: { srid: 4326, type: 'point' }
      t.line_string :line, geographic: true, srid: 4326, has_z: true
      t.string :address_locality
      t.string :street_address
      t.string :postal_code
      t.string :address_country
      t.string :fax_number
      t.string :telephone
      t.string :email
      t.uuid :photo
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index :place_id
    end

    create_table :place_history_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :place_history_id, null: false
      t.string :locale, null: false
      t.string :headline
      t.text :description
      t.string :name
      t.string :url
      t.string :hours_available
      t.string :address
      t.jsonb :content
      t.timestamps
      t.index :id, unique: true, name: 'index_place_history_translation_on_id'
      t.index [:place_history_id, :locale], name: 'index_place_history_id_locale', using: :btree
      t.index :place_history_id, name: 'index_on_place_history_translation_id'
      t.index :locale, name: 'index_place_history_translation_on_locale'
    end

    create_table :creative_works, id: :uuid, primary_key: 'id' do |t|
      t.integer :position
      t.uuid :is_part_of
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index [:template, :template_name], name: 'index_creative_work_template_template_name_idx', using: :btree
      t.index :external_source_id, name: 'index_creative_work_on_external_source_id', using: :btree
      t.index [:external_source_id, :external_key], name: 'index_creative_work_on_external_source_id_and_external_key', unique: true, using: :btree
    end

    create_table :creative_work_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :creative_work_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :headline
      t.text :description
      t.timestamps
      t.index :id, unique: true
      t.index [:creative_work_id, :locale], name: 'index_creative_work_id_locale', using: :btree, unique: true
      t.index :creative_work_id
      t.index :locale
    end

    create_table :creative_work_histories, id: :uuid, primary_key: 'id' do |t|
      t.uuid :creative_work_id
      t.integer :position
      t.uuid :is_part_of
      t.jsonb :metadata
      t.string :template_name
      t.jsonb :schema
      t.boolean :template, null: false, default: false
      t.uuid :external_source_id
      t.string :external_key
      t.uuid :created_by
      t.uuid :updated_by
      t.uuid :deleted_by
      t.datetime :seen_at
      t.timestamps
      t.datetime :deleted_at
      t.index :id, unique: true
      t.index :creative_work_id
    end

    create_table :creative_work_history_translations, id: :uuid, primary_key: 'id' do |t|
      t.uuid :creative_work_history_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.string :headline
      t.text :description
      t.tstzrange :history_valid
      t.timestamps
      t.index :id, unique: true, name: 'index_creative_work_history_translation_on_id'
      t.index [:creative_work_history_id, :locale], name: 'index_creative_work_history_id_locale', using: :btree
      t.index :creative_work_history_id, name: 'index_on_creative_work_history_translation_id'
      t.index :locale, name: 'index_creative_work_history_translation_on_locale'
    end
  end
end

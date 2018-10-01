# frozen_string_literal: true

class RemoveOrganizations < ActiveRecord::Migration[5.1]
  def up
    drop_table :organizations
    drop_table :organization_translations
    drop_table :organization_histories
    drop_table :organization_history_translations
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
      t.index :id, unique: true
      t.index [:organization_history_id, :locale], name: 'index_organization_history_id_locale', using: :btree
      t.index :organization_history_id
      t.index :locale
    end
  end
end

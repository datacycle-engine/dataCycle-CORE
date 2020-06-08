# frozen_string_literal: true

class CreateOrganizationModel < ActiveRecord::Migration[5.0]
  def up
    create_table :organizations, id: :uuid do |t|
      t.jsonb :metadata
      t.boolean :template, null: false, default: false
      t.datetime :seen_at
      t.string :template_name
      t.jsonb :schema
      t.uuid :external_source_id
      t.string :external_key
      t.timestamps
    end

    create_table :organization_translations, id: :uuid do |t|
      t.uuid :organization_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.jsonb :properties
      t.string :headline
      t.text :description
      t.jsonb :release
      t.uuid :release_id
      t.text :release_comment
      t.timestamps
    end

    create_table :organization_histories, id: :uuid do |t|
      t.uuid :organization_id, null: false
      t.jsonb :metadata
      t.boolean :template, null: false, default: false
      t.datetime :seen_at
      t.string :template_name
      t.jsonb :schema
      t.uuid :external_source_id
      t.string :external_key
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :organization_history_translations, id: :uuid do |t|
      t.uuid :organization_history_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.jsonb :properties
      t.string :headline
      t.text :description
      t.jsonb :release
      t.uuid :release_id
      t.text :release_comment
      t.tstzrange :history_valid
      t.timestamps
    end

    add_index :organization_history_translations, :organization_history_id, name: 'organization_history_id_idx'
    add_index :organization_history_translations, :locale, name: 'organization_history_locale_idx'
    add_index :organization_translations, :organization_id, name: 'organization_id_idx'
    add_index :organization_translations, :locale, name: 'organization_locale_idx'
    add_index :organization_histories, :organization_id, name: 'organization_id_foreign_key_idx'
    add_index :organization_histories, :id, name: 'organization_histories_id_idx'
  end

  def down
    drop_table :organizations
    drop_table :organization_translations
    drop_table :organization_histories
    drop_table :organization_history_translations
  end
end

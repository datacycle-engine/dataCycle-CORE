# frozen_string_literal: true

class AddTableForCollectionWithSti < ActiveRecord::Migration[6.1]
  def change
    create_table :collections, id: :uuid do |t|
      t.string :type, null: false
      t.string :name
      t.string :slug
      t.text :description
      t.text :description_stripped
      t.uuid :user_id, index: true
      t.string :full_path
      t.string :full_path_names, array: true
      t.boolean :my_selection, null: false, default: false
      t.boolean :manual_order, null: false, default: false
      t.boolean :api, null: false, default: false
      t.string :language, array: true
      t.uuid :linked_stored_filter_id
      t.jsonb :parameters
      t.jsonb :sort_parameters

      t.datetime :created_at, null: false, default: -> { 'NOW()' }
      t.datetime :updated_at, null: false, default: -> { 'NOW()' }, index: true

      t.index :full_path, using: 'gin', opclass: :gin_trgm_ops
      t.index :slug, unique: true, where: 'slug IS NOT NULL'
      t.index :name, using: 'gin', opclass: :gin_trgm_ops
    end

    add_foreign_key :collections, :users, on_delete: :nullify, on_update: :cascade
    add_foreign_key :collections, :collections, column: :linked_stored_filter_id, on_delete: :nullify, on_update: :cascade

    create_table :collection_concept_scheme_links, id: :uuid do |t|
      t.uuid :collection_id, null: false
      t.uuid :concept_scheme_id, null: false

      t.index [:collection_id, :concept_scheme_id], unique: true, name: 'ccsl_unique_index'
    end

    add_foreign_key :collection_concept_scheme_links, :collections, on_delete: :cascade, on_update: :cascade
    add_foreign_key :collection_concept_scheme_links, :concept_schemes, on_delete: :cascade, on_update: :cascade

    create_table :collection_shares, id: :uuid do |t|
      t.uuid :collection_id, null: false
      t.uuid :shareable_id, null: false
      t.string :shareable_type, null: false, index: true

      t.index [:collection_id, :shareable_id, :shareable_type], unique: true, name: 'collection_shares_unique_index'
    end

    add_foreign_key :collection_shares, :collections, on_delete: :cascade, on_update: :cascade
  end
end

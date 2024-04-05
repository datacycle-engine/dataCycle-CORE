# frozen_string_literal: true

class AddNewTablesForConcepts < ActiveRecord::Migration[6.1]
  def change
    create_table :concepts, id: :uuid do |t|
      t.string :internal_name
      t.jsonb :name_i18n, null: false, default: {}
      t.jsonb :description_i18n, null: false, default: {}
      t.uuid :external_system_id
      t.string :external_key
      t.uuid :concept_scheme_id
      t.integer :order_a, index: true
      t.boolean :assignable, default: true, null: false
      t.boolean :internal, default: false, null: false
      t.string :uri
      t.jsonb :ui_configs, null: false, default: {}
      t.uuid :classification_id, index: true
      t.datetime :created_at, null: false, default: -> { 'NOW()' }
      t.datetime :updated_at, null: false, default: -> { 'NOW()' }

      t.index :internal_name, using: 'gin', opclass: :gin_trgm_ops
      t.index [:external_system_id, :external_key], unique: true, where: 'external_system_id IS NOT NULL AND external_key IS NOT NULL'
    end

    add_foreign_key :concepts, :classification_aliases, column: :id, on_delete: :cascade

    create_table :concept_histories, id: :uuid do |t|
      t.string :internal_name
      t.jsonb :name_i18n, null: false, default: {}
      t.jsonb :description_i18n, null: false, default: {}
      t.uuid :external_system_id
      t.string :external_key
      t.uuid :concept_scheme_id
      t.integer :order_a, index: true
      t.boolean :assignable, default: true, null: false
      t.boolean :internal, default: false, null: false
      t.string :uri
      t.jsonb :ui_configs, null: false, default: {}
      t.uuid :classification_id, index: true
      t.datetime :created_at, null: false, default: -> { 'NOW()' }
      t.datetime :updated_at, null: false, default: -> { 'NOW()' }
      t.datetime :deleted_at, null: false, default: -> { 'NOW()' }, index: true

      t.index :internal_name, using: 'gin', opclass: :gin_trgm_ops
      t.index [:external_system_id, :external_key], unique: true, where: 'external_system_id IS NOT NULL AND external_key IS NOT NULL'
    end

    create_table :concept_schemes, id: :uuid do |t|
      t.string :name, index: true
      t.uuid :external_system_id
      t.boolean :internal, default: false, null: false
      t.string :visibility, null: false, default: [], array: true
      t.string :change_behaviour, null: false, default: [], array: true

      t.datetime :created_at, null: false, default: -> { 'NOW()' }
      t.datetime :updated_at, null: false, default: -> { 'NOW()' }
    end

    add_foreign_key :concept_schemes, :classification_tree_labels, column: :id, on_delete: :cascade
    add_foreign_key :concepts, :concept_schemes, column: :concept_scheme_id, on_delete: :cascade

    create_table :concept_scheme_histories, id: :uuid do |t|
      t.string :name, index: true
      t.uuid :external_system_id
      t.boolean :internal, default: false, null: false
      t.string :visibility, null: false, default: [], array: true
      t.string :change_behaviour, null: false, default: [], array: true

      t.datetime :created_at, null: false, default: -> { 'NOW()' }
      t.datetime :updated_at, null: false, default: -> { 'NOW()' }
      t.datetime :deleted_at, null: false, default: -> { 'NOW()' }, index: true
    end

    create_table :concept_links, id: :uuid do |t|
      t.uuid :parent_id
      t.uuid :child_id, null: false
      t.string :link_type, null: false, default: 'broader', index: true

      t.index [:parent_id, :child_id], unique: true
      t.index :child_id, unique: true, where: "link_type = 'broader'"
    end

    add_foreign_key :concept_links, :concepts, column: :parent_id, on_delete: :cascade
    add_foreign_key :concept_links, :concepts, column: :child_id, on_delete: :cascade

    create_table :concept_link_histories, id: :uuid do |t|
      t.uuid :parent_id
      t.uuid :child_id, null: false
      t.string :link_type, null: false, default: 'broader', index: true
      t.datetime :deleted_at, null: false, default: -> { 'NOW()' }, index: true

      t.index [:parent_id, :child_id], unique: true
      t.index :child_id, unique: true, where: "link_type = 'broader'"
    end
  end
end

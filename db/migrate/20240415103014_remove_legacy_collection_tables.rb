# frozen_string_literal: true

class RemoveLegacyCollectionTables < ActiveRecord::Migration[6.1]
  def change
    drop_table :watch_list_shares, id: :uuid do |t|
      t.uuid :shareable_id
      t.string :shareable_type, default: 'DataCycleCore::UserGroup'
      t.uuid :watch_list_id

      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :seen_at
    end

    drop_table :collection_configurations, id: :uuid do |t|
      t.uuid :watch_list_id
      t.uuid :stored_filter_id
      t.string :slug
      t.text :description
    end

    drop_table :watch_lists, id: :uuid do |t|
      t.string :name
      t.uuid :user_id
      t.string :full_path
      t.string :full_path_names, array: true
      t.boolean :my_selection, null: false, default: false
      t.boolean :manual_order, null: false, default: false
      t.boolean :api, default: false

      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :seen_at
    end

    drop_table :stored_filters, id: :uuid do |t|
      t.string :name
      t.uuid :user_id
      t.string :language, array: true
      t.jsonb :parameters
      t.jsonb :sort_parameters
      t.boolean :system, default: false
      t.boolean :api, default: false
      t.text :api_users, array: true
      t.uuid :linked_stored_filter_id
      t.uuid :classification_tree_labels, array: true

      t.datetime :created_at
      t.datetime :updated_at
    end
  end
end

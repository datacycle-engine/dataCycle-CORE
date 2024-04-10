# frozen_string_literal: true

class AddTablesForContentCollectionLinks < ActiveRecord::Migration[6.1]
  def change
    create_table :content_collection_links, id: :uuid do |t|
      t.uuid :thing_id, index: true
      t.uuid :collection_id
      t.string :collection_type
      t.string :relation, index: true
      t.uuid :stored_filter_id
      t.uuid :watch_list_id
      t.integer :order_a, index: true
      t.datetime :created_at, null: false, default: -> { 'NOW()' }
      t.datetime :updated_at, null: false, default: -> { 'NOW()' }

      t.index [:collection_id, :collection_type], name: 'ccl_collection_index'
      t.index [:thing_id, :relation, :collection_id, :collection_type], unique: true, name: 'ccl_unique_index'
    end

    add_foreign_key :content_collection_links, :things, column: :thing_id, on_delete: :cascade

    create_table :content_collection_link_histories, id: :uuid do |t|
      t.uuid :thing_history_id, index: true
      t.uuid :collection_id
      t.string :collection_type
      t.string :relation, index: true
      t.uuid :stored_filter_id
      t.uuid :watch_list_id
      t.integer :order_a, index: true
      t.datetime :created_at, null: false, default: -> { 'NOW()' }
      t.datetime :updated_at, null: false, default: -> { 'NOW()' }

      t.index [:collection_id, :collection_type], name: 'cclh_collection_index'
    end

    add_foreign_key :content_collection_link_histories, :thing_histories, column: :thing_history_id, on_delete: :cascade
  end
end

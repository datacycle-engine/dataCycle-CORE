# frozen_string_literal: true

class AddTableForStoredFilterCache < ActiveRecord::Migration[7.1]
  def change
    create_table :stored_filter_caches, id: :uuid do |t|
      t.uuid :stored_filter_id, null: false
      t.uuid :thing_id, null: false

      t.index [:stored_filter_id, :thing_id], unique: true
      t.foreign_key :collections, column: :stored_filter_id, on_delete: :cascade
      t.foreign_key :things, column: :thing_id, on_delete: :cascade
    end

    change_table :collections, bulk: true do |t|
      t.integer :cache_ttl
      t.timestamp :cache_updated_at

      t.index [:cache_ttl, :cache_updated_at]
    end
  end
end

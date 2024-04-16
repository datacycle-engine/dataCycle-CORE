# frozen_string_literal: true

class ChangeContentCollectionLinkColumnToGenerated < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE content_collection_links DROP COLUMN IF EXISTS stored_filter_id;

      ALTER TABLE content_collection_links DROP COLUMN IF EXISTS watch_list_id;

      ALTER TABLE content_collection_links
      ADD stored_filter_id uuid generated always AS (CASE
          WHEN collection_type = 'DataCycleCore::StoredFilter' THEN collection_id
        END) stored;

      ALTER TABLE content_collection_links
      ADD watch_list_id uuid generated always AS (CASE
          WHEN collection_type = 'DataCycleCore::WatchList' THEN collection_id
        END) stored;

      ALTER TABLE content_collection_link_histories DROP COLUMN IF EXISTS stored_filter_id;

      ALTER TABLE content_collection_link_histories DROP COLUMN IF EXISTS watch_list_id;

      ALTER TABLE content_collection_link_histories
      ADD COLUMN stored_filter_id uuid generated always AS (
          CASE
            WHEN collection_type = 'DataCycleCore::StoredFilter' THEN collection_id
          END
        ) stored;

      ALTER TABLE content_collection_link_histories
      ADD COLUMN watch_list_id uuid generated always AS (
          CASE
            WHEN collection_type = 'DataCycleCore::WatchList' THEN collection_id
          END
        ) stored;
    SQL

    add_foreign_key :content_collection_links, :stored_filters, column: :stored_filter_id, on_delete: :cascade
    add_foreign_key :content_collection_links, :watch_lists, column: :watch_list_id, on_delete: :cascade
    add_foreign_key :content_collection_link_histories, :stored_filters, column: :stored_filter_id, on_delete: :cascade
    add_foreign_key :content_collection_link_histories, :watch_lists, column: :watch_list_id, on_delete: :cascade
  end

  def down
    remove_foreign_key :content_collection_links, :stored_filters, column: :stored_filter_id
    remove_foreign_key :content_collection_links, :watch_lists, column: :watch_list_id
    remove_foreign_key :content_collection_link_histories, :stored_filters, column: :stored_filter_id
    remove_foreign_key :content_collection_link_histories, :watch_lists, column: :watch_list_id
  end
end

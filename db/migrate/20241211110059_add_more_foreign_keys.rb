# frozen_string_literal: true

class AddMoreForeignKeys < ActiveRecord::Migration[7.1]
  def up
    add_foreign_key :searches, :things, column: :content_data_id, on_delete: :cascade, validate: false
    add_foreign_key :schedules, :things, column: :thing_id, on_delete: :cascade, validate: false
    add_foreign_key :schedule_histories, :thing_histories, column: :thing_history_id, on_delete: :cascade, validate: false
    add_foreign_key :thing_duplicates, :things, column: :thing_id, on_delete: :cascade, validate: false
    add_foreign_key :thing_duplicates, :things, column: :thing_duplicate_id, on_delete: :cascade, validate: false

    rename_column :watch_list_data_hashes, :hashable_id, :thing_id
    remove_index :watch_list_data_hashes, name: :by_watch_list_hashable, if_exists: true
    add_index :watch_list_data_hashes, [:watch_list_id, :thing_id], unique: true, name: :by_watch_list_thing, if_not_exists: true

    execute <<-SQL.squish
      DROP VIEW IF EXISTS public.content_items;

      CREATE VIEW public.content_items(
        data_link_id,
        content_type,
        content_id,
        creator_id,
        receiver_id
      ) AS (
        SELECT data_links.id AS data_link_id,
          'DataCycleCore::Thing' AS content_type,
          thing_id AS content_id,
          creator_id,
          receiver_id
        FROM data_links
          JOIN watch_list_data_hashes ON watch_list_id = item_id
        WHERE item_type = 'DataCycleCore::WatchList'
        UNION
        SELECT data_links.id AS data_link_id,
          item_type AS content_type,
          item_id AS content_id,
          creator_id,
          receiver_id
        FROM data_links
        WHERE item_type <> 'DataCycleCore::WatchList'
      );
    SQL

    remove_column :watch_list_data_hashes, :hashable_type

    add_foreign_key :watch_list_data_hashes, :things, column: :thing_id, on_delete: :cascade, validate: false
    add_foreign_key :thing_translations, :things, column: :thing_id, on_delete: :cascade, validate: false
    add_foreign_key :thing_history_translations, :thing_histories, column: :thing_history_id, on_delete: :cascade, validate: false
    add_foreign_key :subscriptions, :users, column: :user_id, on_delete: :cascade, validate: false
    add_foreign_key :data_links, :users, column: :creator_id, on_delete: :cascade, validate: false
    add_foreign_key :data_links, :users, column: :receiver_id, on_delete: :cascade, validate: false
    add_foreign_key :activities, :users, column: :user_id, on_delete: :nullify, validate: false
    add_foreign_key :content_contents, :things, column: :content_a_id, on_delete: :cascade, validate: false
    add_foreign_key :content_contents, :things, column: :content_b_id, on_delete: :cascade, validate: false
  end

  def down
  end
end

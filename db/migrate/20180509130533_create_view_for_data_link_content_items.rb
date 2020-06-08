# frozen_string_literal: true

class CreateViewForDataLinkContentItems < ActiveRecord::Migration[5.0]
  def up
    execute <<-SQL
      CREATE VIEW content_items(data_link_id, content_type, content_id, creator_id, receiver_id) AS (
        SELECT
          data_links.id AS data_link_id,
          hashable_type AS content_type,
          hashable_id AS content_id,
          creator_id,
          receiver_id
        FROM data_links
        JOIN watch_list_data_hashes ON watch_list_id = item_id
        WHERE item_type = 'DataCycleCore::WatchList'
      UNION
        SELECT
          data_links.id AS data_link_id,
          item_type AS content_type,
          item_id AS content_id,
          creator_id,
          receiver_id
        FROM data_links
        WHERE item_type <> 'DataCycleCore::WatchList'
      );
    SQL
  end

  def down
    execute <<-SQL
      DROP VIEW content_items;
    SQL
  end
end

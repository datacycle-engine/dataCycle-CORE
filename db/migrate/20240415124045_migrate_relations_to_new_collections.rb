# frozen_string_literal: true

class MigrateRelationsToNewCollections < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      UPDATE data_links
      SET item_type = 'DataCycleCore::Collection'
      WHERE item_type IN (
          'DataCycleCore::WatchList',
          'DataCycleCore::StoredFilter'
        );

      UPDATE subscriptions
      SET subscribable_type = 'DataCycleCore::Collection'
      WHERE subscribable_type IN (
          'DataCycleCore::WatchList',
          'DataCycleCore::StoredFilter'
        );
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE data_links
      SET item_type = collections.type
      FROM collections
      WHERE collections.id = data_links.item_id
        AND data_links.item_type = 'DataCycleCore::Collection';

      UPDATE subscriptions
      SET subscribable_type = collections.type
      FROM collections
      WHERE collections.id = subscriptions.subscribable_id
        AND subscriptions.subscribable_type = 'DataCycleCore::Collection';
    SQL
  end
end

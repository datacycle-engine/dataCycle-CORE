# frozen_string_literal: true

class CreateTableWatchlistUserGroups < ActiveRecord::Migration[5.1]
  def up
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    create_table :watch_list_user_groups, id: :uuid do |t|
      t.uuid :user_group_id
      t.uuid :watch_list_id
      t.datetime :seen_at
      t.timestamps
      t.index :user_group_id
      t.index :watch_list_id
    end
  end

  def down
    drop_table :watch_list_user_groups
  end
end

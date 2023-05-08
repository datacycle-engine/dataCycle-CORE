# frozen_string_literal: true

class ChangeWatchListUserGroupsToWatchListShares < ActiveRecord::Migration[5.1]
  def change
    rename_table :watch_list_user_groups, :watch_list_shares
    rename_column :watch_list_shares, :user_group_id, :shareable_id
    add_column :watch_list_shares, :shareable_type, :string, default: 'DataCycleCore::UserGroup'
    change_column_default :users, :type, from: nil, to: 'DataCycleCore::User'

    remove_index :watch_list_shares, :shareable_id if index_exists?(:watch_list_shares, :shareable_id)
    add_index :watch_list_shares, [:shareable_id, :shareable_type, :watch_list_id], unique: true, name: 'unique_by_shareable'

    DataCycleCore::User.with_deleted.where(type: nil).update(type: 'DataCycleCore::User')
  end
end

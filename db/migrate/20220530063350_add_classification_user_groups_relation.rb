# frozen_string_literal: true

class AddClassificationUserGroupsRelation < ActiveRecord::Migration[6.1]
  def change
    create_table :classification_user_groups, if_not_exists: true, id: :uuid do |t|
      t.uuid :classification_id
      t.uuid :user_group_id
      t.datetime :seen_at
      t.timestamps
      t.index :classification_id
      t.index :user_group_id
    end
  end
end

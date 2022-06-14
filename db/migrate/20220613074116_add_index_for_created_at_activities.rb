# frozen_string_literal: true

class AddIndexForCreatedAtActivities < ActiveRecord::Migration[6.1]
  def change
    add_index :activities, [:user_id, :activity_type, :created_at], name: 'index_activities_on_user_id_activity_type_created_at', if_not_exists: true
  end
end

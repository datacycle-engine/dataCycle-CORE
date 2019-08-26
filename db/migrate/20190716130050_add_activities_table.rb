# frozen_string_literal: true

class AddActivitiesTable < ActiveRecord::Migration[5.2]
  def change
    create_table :activities, id: :uuid do |t|
      t.references :activitiable, polymorphic: true, type: :uuid, index: true
      t.references :user, type: :uuid, index: true
      t.string :activity_type
      t.jsonb :data
      t.timestamps
    end
    add_index :activities, [:activity_type, :updated_at]
  end
end

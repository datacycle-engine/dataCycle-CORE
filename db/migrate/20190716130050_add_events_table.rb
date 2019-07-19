# frozen_string_literal: true

class AddEventsTable < ActiveRecord::Migration[5.2]
  def change
    create_table :events, id: :uuid do |t|
      t.references :eventable, polymorphic: true, type: :uuid, index: true
      t.references :user, type: :uuid, index: true
      t.string :event_type

      t.timestamps
    end
    add_index :events, [:event_type, :updated_at]
  end
end

# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[5.0]
  def up
    create_table :subscriptions, id: :uuid do |t|
      t.uuid :user_id
      t.uuid :subscribable_id
      t.string :subscribable_type
      t.timestamps
      t.index :user_id
      t.index :subscribable_id
      t.index :subscribable_type
    end
  end

  def down
    drop_table :subscriptions
  end
end

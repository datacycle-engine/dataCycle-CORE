# frozen_string_literal: true

class AddTableStoredFilter < ActiveRecord::Migration[5.0]
  def change
    create_table :stored_filters, id: :uuid do |t|
      t.string :name
      t.uuid :user_id
      t.string :language
      t.jsonb :parameters
      t.boolean :system, default: false, null: false
      t.boolean :api, default: false, null: false
      t.timestamps
    end

    add_index :stored_filters, :user_id
    add_index :stored_filters, [:api, :system, :name], name: 'classified_name_idx'
  end
end

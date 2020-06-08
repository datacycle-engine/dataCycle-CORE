# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[5.0]
  def up
    create_table :events, id: :uuid do |t|
      t.string :headline
      t.text :description
      t.datetime :startDate
      t.datetime :endDate
      t.jsonb :metadata
      t.boolean :template, null: false, default: false
      t.datetime :seen_at
      t.timestamps
    end

    create_table :creative_work_events, id: :uuid do |t|
      t.uuid :creative_work_id
      t.uuid :event_id
      t.datetime :seen_at
      t.timestamps
      t.index :creative_work_id
      t.index :event_id
    end

    create_table :classification_events, id: :uuid do |t|
      t.uuid :event_id
      t.uuid :classification_id
      t.boolean :tag, default: false, null: false
      t.boolean :classification, default: false, null: false
      t.datetime :seen_at
      t.timestamps
      t.index :event_id
      t.index :classification_id
    end

    create_table :event_translations do |t|
      t.uuid :event_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.jsonb :properties
      t.timestamps
    end
  end

  def down
    drop_table :events
    drop_table :creative_work_events
    drop_table :classification_events
    drop_table :event_translations
  end
end

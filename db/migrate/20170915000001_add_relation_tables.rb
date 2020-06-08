# frozen_string_literal: true

class AddRelationTables < ActiveRecord::Migration[5.0]
  def change
    create_table :event_persons, id: :uuid do |t|
      t.uuid :event_id
      t.uuid :person_id
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :event_places, id: :uuid do |t|
      t.uuid :event_id
      t.uuid :place_id
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :person_places, id: :uuid do |t|
      t.uuid :person_id
      t.uuid :place_id
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end
  end
end

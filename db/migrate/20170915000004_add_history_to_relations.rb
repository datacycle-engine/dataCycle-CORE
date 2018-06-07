# frozen_string_literal: true

class AddHistoryToRelations < ActiveRecord::Migration[5.0]
  def up
    create_table :creative_work_event_histories, id: :uuid do |t|
      t.uuid :creative_work_history_id
      t.uuid :event_history_id
      t.tstzrange :history_valid
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :creative_work_person_histories, id: :uuid do |t|
      t.uuid :creative_work_history_id
      t.uuid :person_history_id
      t.tstzrange :history_valid
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :creative_work_place_histories, id: :uuid do |t|
      t.uuid :creative_work_history_id
      t.uuid :place_history_id
      t.tstzrange :history_valid
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :event_person_histories, id: :uuid do |t|
      t.uuid :event_history_id
      t.uuid :person_history_id
      t.tstzrange :history_valid
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :event_place_histories, id: :uuid do |t|
      t.uuid :event_history_id
      t.uuid :place_history_id
      t.tstzrange :history_valid
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :person_place_histories, id: :uuid do |t|
      t.uuid :person_history_id
      t.uuid :place_history_id
      t.tstzrange :history_valid
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end
  end

  def down
    drop_table :person_place_histories
    drop_table :event_place_histories
    drop_table :event_person_histories
    drop_table :creative_work_place_histories
    drop_table :creative_work_person_histories
    drop_table :creative_work_event_histories
  end
end

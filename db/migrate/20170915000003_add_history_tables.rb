# frozen_string_literal: true

class AddHistoryTables < ActiveRecord::Migration[5.0]
  # rubocop:disable Rails/BulkChangeTable
  def up
    # creative_works
    create_table :creative_work_histories, id: :uuid do |t|
      t.uuid :creative_work_id
      t.integer :position
      t.uuid :isPartOf
      t.jsonb :metadata
      t.boolean :template, null: false, default: false
      t.datetime :seen_at
      t.uuid :external_source_id
      t.timestamps
    end

    create_table :creative_work_history_translations do |t|
      t.uuid :creative_work_history_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.jsonb :properties
      t.text :headline
      t.text :description
      t.jsonb :release
      t.uuid :release_id
      t.text :release_comment
      t.tstzrange :history_valid
      t.timestamps
    end

    create_table :classification_creative_work_histories, id: :uuid do |t|
      t.uuid :creative_work_history_id
      t.uuid :classification_id
      t.boolean :tag, default: false, null: false
      t.boolean :classification, default: false, null: false
      t.datetime :seen_at
      t.timestamps
      t.uuid :external_source_id
    end

    # events
    add_column :events, :external_source_id, :uuid
    add_column :classification_events, :external_source_id, :uuid

    create_table :event_histories, id: :uuid do |t|
      t.uuid :event_id
      t.datetime :startDate
      t.datetime :endDate
      t.jsonb :metadata
      t.boolean :template, null: false, default: false
      t.datetime :seen_at
      t.uuid :external_source_id
      t.timestamps
    end

    create_table :event_history_translations do |t|
      t.uuid :event_history_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.jsonb :properties
      t.text :headline
      t.text :description
      t.jsonb :release
      t.uuid :release_id
      t.text :release_comment
      t.tstzrange :history_valid
      t.timestamps
    end

    create_table :classification_event_histories, id: :uuid do |t|
      t.uuid :event_history_id
      t.uuid :classification_id
      t.boolean :tag, default: false, null: false
      t.boolean :classification, default: false, null: false
      t.datetime :seen_at
      t.timestamps
      t.uuid :external_source_id
    end

    # persons
    add_column :persons, :external_source_id, :uuid
    add_column :classification_persons, :external_source_id, :uuid

    create_table :person_histories, id: :uuid do |t|
      t.uuid :person_id
      t.string :givenName
      t.string :familyName
      t.jsonb :metadata
      t.boolean :template, null: false, default: false
      t.datetime :seen_at
      t.uuid :external_source_id
      t.timestamps
    end

    create_table :person_history_translations do |t|
      t.uuid :person_history_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.jsonb :properties
      t.text :headline
      t.text :description
      t.jsonb :release
      t.uuid :release_id
      t.text :release_comment
      t.tstzrange :history_valid
      t.timestamps
    end

    create_table :classification_person_histories, id: :uuid do |t|
      t.uuid :person_history_id
      t.uuid :classification_id
      t.boolean :tag, default: false, null: false
      t.boolean :classification, default: false, null: false
      t.datetime :seen_at
      t.timestamps
      t.uuid :external_source_id
    end

    # places
    add_column :classification_places, :tag, :boolean, null: false, default: false
    add_column :classification_places, :classification, :boolean, null: false, default: false

    create_table :place_histories, id: :uuid do |t|
      t.uuid :place_id
      t.string :external_key
      t.float :longitude
      t.float :latitude
      t.float :elevation
      t.st_point :location, srid: 4326
      t.line_string :line, srid: 4326, geographic: true, has_z: true
      t.uuid :photo
      t.jsonb :metadata
      t.boolean :template, null: false, default: false
      t.datetime :seen_at
      t.uuid :external_source_id
      t.timestamps
    end

    create_table :place_history_translations do |t|
      t.uuid :place_history_id, null: false
      t.string :locale, null: false
      t.string :name
      t.string :addressLocality
      t.string :streetAddress
      t.string :postalCode
      t.string :addressCountry
      t.string :faxNumber
      t.string :telephone
      t.string :email
      t.string :url
      t.string :hoursAvailable
      t.string :address
      t.jsonb :content
      t.jsonb :properties
      t.text :headline
      t.text :description
      t.jsonb :release
      t.uuid :release_id
      t.text :release_comment
      t.tstzrange :history_valid
      t.timestamps
    end

    create_table :classification_place_histories, id: :uuid do |t|
      t.uuid :place_history_id
      t.uuid :classification_id
      t.boolean :tag, default: false, null: false
      t.boolean :classification, default: false, null: false
      t.datetime :seen_at
      t.timestamps
      t.uuid :external_source_id
    end
  end

  def down
    drop_table :classification_place_histories
    drop_table :place_history_translations
    drop_table :place_histories
    remove_column :classification_places, :classification
    remove_column :classification_places, :tag

    drop_table :classification_person_histories
    drop_table :person_history_translations
    drop_table :person_histories
    remove_column :classification_persons, :external_source_id
    remove_column :person, :external_source_id

    drop_table :classification_event_histories
    drop_table :event_history_translations
    drop_table :event_histories
    remove_column :classification_event_histories, :external_source_id
    remove_column :events, :external_source_id

    drop_table :classification_creative_work_histories
    drop_table :creative_work_history_translations
    drop_table :creative_work_histories
  end
  # rubocop:enable Rails/BulkChangeTable
end

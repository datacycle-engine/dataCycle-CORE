class AddHistoryTables < ActiveRecord::Migration[5.0]
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

    DataCycleCore::CreativeWork::History.create_translation_table!({
      content: :jsonb,
      properties: :jsonb,
      headline: :text,
      description: :text,
      release: :jsonb,
      release_id: :uuid,
      release_comment: :text,
      history_valid: :tstzrange
    })

    create_table :classification_creative_work_histories, id: :uuid do |t|
      t.uuid :creative_work_history_id
      t.uuid :classification_id
      t.boolean :tag
      t.boolean :classification
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

    DataCycleCore::Event::History.create_translation_table!({
      content: :jsonb,
      properties: :jsonb,
      headline: :text,
      description: :text,
      release: :jsonb,
      release_id: :uuid,
      release_comment: :text,
      history_valid: :tstzrange
    })

    create_table :classification_event_histories, id: :uuid do |t|
      t.uuid :event_history_id
      t.uuid :classification_id
      t.boolean :tag
      t.boolean :classification
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

    DataCycleCore::Person::History.create_translation_table!({
      content: :jsonb,
      properties: :jsonb,
      headline: :text,
      description: :text,
      release: :jsonb,
      release_id: :uuid,
      release_comment: :text,
      history_valid: :tstzrange
    })

    create_table :classification_person_histories, id: :uuid do |t|
      t.uuid :person_history_id
      t.uuid :classification_id
      t.boolean :tag
      t.boolean :classification
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

    DataCycleCore::Place::History.create_translation_table!({
      name: :string,
      addressLocality: :string,
      streetAddress: :string,
      postalCode: :string,
      addressCountry: :string,
      faxNumber: :string,
      telephone: :string,
      email: :string,
      url: :string,
      hoursAvailable: :string,
      address: :string, # MO: should be later deleted (as of now its gone from DataCycleCore::Place)
      content: :jsonb,
      properties: :jsonb,
      headline: :text,
      description: :text,
      release: :jsonb,
      release_id: :uuid,
      release_comment: :text,
      history_valid: :tstzrange
    })

    create_table :classification_place_histories, id: :uuid do |t|
      t.uuid :place_history_id
      t.uuid :classification_id
      t.boolean :tag
      t.boolean :classification
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
end

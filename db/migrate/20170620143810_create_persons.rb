# frozen_string_literal: true

class CreatePersons < ActiveRecord::Migration[5.0]
  def up
    create_table :persons, id: :uuid do |t|
      t.string :headline
      t.text :description
      t.string :givenName
      t.string :familyName
      t.jsonb :metadata
      t.boolean :template, null: false, default: false
      t.datetime :seen_at
      t.timestamps
    end

    create_table :creative_work_persons, id: :uuid do |t|
      t.uuid :creative_work_id
      t.uuid :person_id
      t.datetime :seen_at
      t.timestamps
      t.index :creative_work_id
      t.index :person_id
    end

    create_table :person_translations do |t|
      t.uuid :person_id, null: false
      t.string :locale, null: false
      t.jsonb :content
      t.jsonb :properties
      t.timestamps
    end
  end

  def down
    drop_table :persons
    drop_table :creative_work_persons
    drop_table :person_translations
  end
end

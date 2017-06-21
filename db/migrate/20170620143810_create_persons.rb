class CreatePersons < ActiveRecord::Migration[5.0]

  def up

    create_table :persons, id: :uuid do |t|
      t.string :headline
      t.text :description
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

    DataCycleCore::Person.create_translation_table!({
      content: :jsonb,
      properties: :jsonb
    })

  end

  def down
    drop_table :persons
    drop_table :creative_work_persons
    DataCycleCore::Person.drop_translation_table!
  end

end

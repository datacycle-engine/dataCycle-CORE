# frozen_string_literal: true

class AddClassificationToPersons < ActiveRecord::Migration[5.0]
  def up
    create_table :classification_persons, id: :uuid do |t|
      t.uuid :person_id
      t.uuid :classification_id
      t.boolean :tag, default: false, null: false
      t.boolean :classification, default: false, null: false
      t.datetime :seen_at
      t.timestamps
      t.index :person_id
      t.index :classification_id
    end
  end

  def down
    drop_table :classification_persons
  end
end

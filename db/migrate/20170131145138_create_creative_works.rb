# frozen_string_literal: true

class CreateCreativeWorks < ActiveRecord::Migration[5.0]
  # rubocop:disable Rails/BulkChangeTable

  def up
    create_table :place_translations do |t|
      t.uuid :place_id, null: false
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
      t.timestamps
    end

    remove_column :places, :name
    remove_column :places, :streetAddress
    remove_column :places, :postalCode
    remove_column :places, :addressCountry
    remove_column :places, :faxNumber
    remove_column :places, :telephone
    remove_column :places, :email
    remove_column :places, :url
    remove_column :places, :hoursAvailable

    create_table :creative_works, id: :uuid do |t|
      t.string :headline
      t.text :description
      t.integer :position, default: 0, null: 0
      t.uuid :isPartOf # parent_id
      t.jsonb :metadata
      t.datetime :seen_at
      t.timestamps
    end

    create_table :creative_works_places, id: :uuid do |t|
      t.uuid :creative_work_id
      t.uuid :place_id
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :classifications_creative_works, id: :uuid do |t|
      t.uuid :creative_work_id
      t.uuid :classifications_alias_id
      t.boolean :tag, default: false, null: false
      t.boolean :classification, default: false, null: false
      t.datetime :seen_at
      t.timestamps
    end
  end

  def down
    drop_table :classifications_creative_works
    drop_table :creative_works_places
    drop_table :creative_works
    drop_table :place_translations

    add_column :places, :name, :string
    add_column :places, :streetAddress, :string
    add_column :places, :postalCode, :string
    add_column :places, :addressCountry, :string
    add_column :places, :faxNumber, :string
    add_column :places, :telephone, :string
    add_column :places, :email, :string
    add_column :places, :url, :string
    add_column :places, :hoursAvailable, :string
  end

  # rubocop:enable Rails/BulkChangeTable
end

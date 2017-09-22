class CreateCreativeWorks < ActiveRecord::Migration[5.0]

  def up

    I18n.with_locale(:de) do
      DataCycleCore::Place.create_translation_table!({
        name: :string,
        addressLocality: :string,
        streetAddress: :string,
        postalCode: :string,
        addressCountry: :string,
        faxNumber: :string,
        telephone: :string,
        email: :string,
        url: :string,
        hoursAvailable: :string
      }, {
        :migrate_data => true,
        :remove_source_columns => true
      })
    end

    create_table :creative_works, id: :uuid do |t|
      t.string :headline
      t.text :description
      t.integer :position, default: 0, null: 0
      t.uuid :isPartOf  # parent_id
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
    DataCycleCore::Place.drop_translation_table! :migrate_data => true
  end

end

# frozen_string_literal: true

class DeleteImages < ActiveRecord::Migration[5.0]
  def up
    drop_table :images
    drop_table :images_places
  end

  def down
    create_table :images, id: :uuid do |t|
      t.string :title
      t.string :author
      t.boolean :primary, default: false, null: false
      t.string :url
      t.jsonb :meta
      t.uuid :external_source_id
      t.string :external_key
      t.datetime :seen_at
      t.timestamps
      t.index ['external_source_id', 'id'], name: 'index_images_on_external_source_id_and_id', unique: true, using: :btree
      t.index ['external_source_id'], name: 'index_images_on_external_source_id', using: :btree
    end

    create_table :images_places, id: :uuid do |t|
      t.uuid :place_id
      t.uuid :image_id
      t.uuid :external_source_id
      t.string :external_place_key
      t.string :external_image_key
      t.datetime :seen_at
      t.timestamps
      t.index ['external_source_id', 'place_id', 'image_id'], name: 'place_image_index', unique: true, using: :btree
      t.index ['external_source_id'], name: 'index_images_places_on_external_source_id', using: :btree
      t.index ['image_id'], name: 'index_images_places_on_image_id', using: :btree
      t.index ['place_id'], name: 'index_images_places_on_place_id', using: :btree
    end
  end
end

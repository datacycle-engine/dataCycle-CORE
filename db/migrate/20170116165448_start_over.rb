# frozen_string_literal: true

class StartOver < ActiveRecord::Migration[5.0]
  def change
    enable_extension 'postgis' unless extension_enabled?('postgis')
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :tags, id: :uuid do |t|
      t.string   :name
      t.datetime :seen_at
      t.timestamps
    end

    create_table :classifications, id: :uuid do |t|
      t.string   :name
      t.uuid     :external_source_id
      t.string   :external_key
      t.string   :description
      t.datetime :seen_at
      t.geometry :location,           limit: { srid: 4326, type: 'point' }
      t.geometry :bbox,               limit: { srid: 4326, type: 'polygon' }
      t.geometry :shape,              limit: { srid: 4326, type: 'multi_polygon' }
      t.string   :external_type
      t.timestamps
    end

    create_table :classifications_aliases, id: :uuid do |t|
      t.string   :name
      t.datetime :seen_at
      t.timestamps
    end

    create_table :classifications_groups, id: :uuid do |t|
      t.uuid  :classification_id
      t.uuid  :classifications_alias_id
      t.uuid  :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :classifications_places, id: :uuid do |t|
      t.uuid  :place_id
      t.uuid  :classification_id
      t.uuid  :external_source_id
      t.datetime :seen_at
      t.timestamps
      t.index ['classification_id'], name: 'index_classifications_places_on_classification_id', using: :btree
      t.index ['external_source_id', 'place_id', 'classification_id'], name: 'place_classification_index', unique: true, using: :btree
      t.index ['place_id'], name: 'index_classifications_places_on_place_id', using: :btree
    end

    create_table :classifications_trees, id: :uuid do |t|
      t.uuid :external_source_id
      t.uuid :parent_classifications_alias_id
      t.uuid :classifications_alias_id
      t.string :relationship_label
      t.uuid :classifications_trees_label_id
      t.datetime :seen_at
      t.timestamps
      t.index ['classifications_alias_id', 'parent_classifications_alias_id'], name: 'child_parent_index', unique: true, using: :btree
      t.index ['classifications_alias_id'], name: 'index_classifications_trees_on_classifications_alias_id', using: :btree
      t.index ['parent_classifications_alias_id', 'classifications_alias_id'], name: 'parent_child_index', unique: true, using: :btree
      t.index ['parent_classifications_alias_id'], name: 'index_classifications_trees_on_parent_classifications_alias_id', using: :btree
    end

    create_table :classifications_trees_labels, id: :uuid do |t|
      t.string :name
      t.uuid :external_source_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :external_sources, id: :uuid do |t|
      t.string :external_name
      t.jsonb  :credentials
      t.jsonb  :config
      t.index ['id'], name: 'index_external_sources_on_id', unique: true, using: :btree
    end

    create_table :overlays, id: :uuid do |t|
      t.jsonb    :overlay_data
      t.datetime :seen_at
      t.timestamps
    end

    create_table :overlays_places_tags, id: :uuid do |t|
      t.uuid :overlay_id
      t.uuid :place_id
      t.uuid :tag_id
      t.datetime :seen_at
      t.timestamps
    end

    create_table :places, id: :uuid do |t|
      t.string :name
      t.string :description
      t.uuid :external_source_id
      t.string :external_key
      t.float :longitude
      t.float :latitude
      t.float :elevation
      t.geometry :location, limit: { srid: 4326, type: 'point' }
      t.string :addressLocality
      t.string :streetAddress
      t.string :postalCode
      t.string :addressCountry
      t.string :faxNumber
      t.string :telephone
      t.string :email
      t.string :url
      t.string :hoursAvailable
      t.datetime :seen_at
      t.timestamps
      t.index ['external_source_id', 'external_key'], name: 'index_places_on_external_source_id_and_external_key', unique: true, using: :btree
      t.index ['external_source_id'], name: 'index_places_on_external_source_id', using: :btree
    end

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

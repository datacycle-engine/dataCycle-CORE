# frozen_string_literal: true

class AddMissingIndexes < ActiveRecord::Migration[5.0]
  def change
    add_index :classification_aliases, :id, unique: true

    add_index :classification_groups, :classification_id
    add_index :classification_groups, :classification_alias_id
    add_index :classification_groups, :external_source_id

    add_index :classification_tree_labels, :id, unique: true
    add_index :classification_tree_labels, :external_source_id, name: :by_ctl_esi

    add_index :classifications, :id, unique: true
    add_index :classifications, :external_source_id

    add_index :creative_work_places, :creative_work_id
    add_index :creative_work_places, :place_id
    add_index :creative_work_places, :external_source_id, name: :by_cwp_esi

    add_index :creative_work_translations, [:creative_work_id, :locale], unique: true, name: :by_cwt_cwi_locale

    add_index :creative_works, :id, unique: true
    add_index :creative_works, :isPartOf
    add_index :creative_works, :external_source_id

    add_index :overlay_place_tags, :overlay_id
    add_index :overlay_place_tags, :place_id
    add_index :overlay_place_tags, :tag_id

    add_index :overlays, :id, unique: true

    add_index :place_translations, [:place_id, :locale], unique: true, name: :by_pt_p_locale

    add_index :places, :id, unique: true
    add_index :places, :location, using: :gist

    add_index :tags, :id, unique: true

    add_index :use_cases, :id, unique: true
    add_index :use_cases, :user_id
    add_index :use_cases, :external_source_id

    add_index :users, :id, unique: true

    add_index :classification_creative_works, :creative_work_id
    add_index :classification_creative_works, :classification_alias_id
  end
end

# frozen_string_literal: true

class ChangeToRailsStandard < ActiveRecord::Migration[5.0]
  def change
    rename_table :overlays_places_tags, :overlay_place_tags

    rename_column :external_sources, :external_name, :name

    rename_table :creative_works_places, :creative_work_places

    rename_table :classifications_aliases, :classification_aliases

    rename_table :classifications_groups, :classification_groups
    rename_column :classification_groups, :classifications_alias_id, :classification_alias_id

    rename_table :classifications_trees, :classification_trees
    rename_column :classification_trees, :parent_classifications_alias_id, :parent_classification_alias_id
    rename_column :classification_trees, :classifications_alias_id, :classification_alias_id
    rename_column :classification_trees, :classifications_trees_label_id, :classification_tree_label_id

    rename_table :classifications_trees_labels, :classification_tree_labels

    rename_table :classifications_creative_works, :classification_creative_works
    rename_column :classification_creative_works, :classifications_alias_id, :classification_alias_id

    rename_table :classifications_places, :classification_places
  end
end

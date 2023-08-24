# frozen_string_literal: true

class AddIndexForClassificationPolygonsClassificationAliasId < ActiveRecord::Migration[6.1]
  def change
    add_index :classification_polygons, [:classification_alias_id, :id], name: :classification_polygons_classification_alias_id_id_idx, if_not_exists: true
  end
end

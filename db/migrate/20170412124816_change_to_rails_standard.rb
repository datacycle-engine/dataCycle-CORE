class ChangeToRailsStandard < ActiveRecord::Migration[5.0]
  def change
    rename_table :overlays_places_tags, :overlay_place_tags
    rename_column :external_sources, :external_name, :name
    rename_table :creative_works_places, :creative_work_places
  end
end

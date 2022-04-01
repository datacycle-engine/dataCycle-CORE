# frozen_string_literal: true

class DropTagAndOverlayTables < ActiveRecord::Migration[5.0]
  def up
    drop_table :tags
    drop_table :overlays
    drop_table :overlay_place_tags
  end

  def down
    # irreversible
  end
end

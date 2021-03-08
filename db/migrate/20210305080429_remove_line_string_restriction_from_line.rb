# frozen_string_literal: true

class RemoveLineStringRestrictionFromLine < ActiveRecord::Migration[5.2]
  def up
    remove_column :things, :line
    add_column :things, :line, :multi_line_string, srid: 4326, has_z: true
  end

  def down
    change_column :things, :line, :line_string, geographic: true, srid: 4326, has_z: true
  end
end

# frozen_string_literal: true

class RemoveLineStringRestrictionFromLine < ActiveRecord::Migration[5.2]
  # rubocop:disable Rails/BulkChangeTable
  def up
    remove_column :things, :line
    add_column :things, :line, :multi_line_string, srid: 4326, has_z: true
    remove_column :thing_histories, :line
    add_column :thing_histories, :line, :multi_line_string, srid: 4326, has_z: true
  end

  def down
    remove_column :things, :line
    add_column :things, :line, :line_string, geographic: true, srid: 4326, has_z: true
    remove_column :thing_histories, :line
    add_column :thing_histories, :line, :line_string, geographic: true, srid: 4326, has_z: true
  end
  # rubocop:enable Rails/BulkChangeTable
end

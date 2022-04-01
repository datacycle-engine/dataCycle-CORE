# frozen_string_literal: true

class AddColumnForHistoryToThings < ActiveRecord::Migration[5.2]
  def up
    add_column :things, :write_history, :boolean, default: false

    execute <<~SQL.squish
      UPDATE
        things
      SET
        write_history = TRUE
      WHERE
        TEMPLATE = FALSE
        AND content_type != 'embedded'
        AND (updated_by IS NOT NULL
          OR external_source_id IS NULL)
    SQL
  end

  def down
    remove_column :things, :write_history
  end
end

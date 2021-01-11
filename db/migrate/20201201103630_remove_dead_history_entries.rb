# frozen_string_literal: true

class RemoveDeadHistoryEntries < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      DELETE FROM thing_history_translations
      WHERE upper(history_valid) IS NULL
      OR lower(history_valid) IS NULL
    SQL

    execute <<-SQL.squish
      UPDATE content_content_histories
      SET history_valid = thing_history_translations.history_valid
      FROM thing_history_translations
      WHERE content_content_histories.content_a_history_id = thing_history_translations.thing_history_id
      AND (
        upper(content_content_histories.history_valid) IS NULL
        OR lower(content_content_histories.history_valid) IS NULL
      )
    SQL

    execute <<-SQL.squish
      DELETE FROM content_content_histories
      WHERE upper(history_valid) IS NULL
      OR lower(history_valid) IS NULL
    SQL
  end

  def down
  end
end

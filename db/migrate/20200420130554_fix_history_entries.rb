# frozen_string_literal: true

class FixHistoryEntries < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      UPDATE thing_history_translations
      SET history_valid = tstzrange(
          v_table_name.new_lower,
          upper(history_valid),
          concat(
              '[',
              CASE WHEN upper_inc(history_valid) THEN ']' ELSE ')' END
          )
      )
      FROM
      (
          SELECT lag(upper(thing_history_translations.history_valid), 1, LEAST(lower(thing_history_translations.history_valid), things.created_at::timestamp with time zone)) OVER (PARTITION BY thing_histories.thing_id, thing_history_translations.locale ORDER BY upper(thing_history_translations.history_valid) ASC) AS new_lower, thing_history_translations.id
          FROM thing_history_translations
          INNER JOIN thing_histories
          ON thing_history_translations.thing_history_id = thing_histories.id
          INNER JOIN things
          ON thing_histories.thing_id = things.id
      ) AS v_table_name
      WHERE thing_history_translations.id = v_table_name.id
      AND v_table_name.new_lower IS NOT NULL;
    SQL
  end

  def down
  end
end

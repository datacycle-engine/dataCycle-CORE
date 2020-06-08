# frozen_string_literal: true

class FixHistoryValidLowerExclusiveBounds < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      UPDATE thing_history_translations
      SET history_valid = tstzrange(
              lower(thing_history_translations.history_valid),
              upper(thing_history_translations.history_valid),
              concat(
                  '[',
                  CASE WHEN upper_inc(thing_history_translations.history_valid) THEN ']' ELSE ')' END
              )
          )
      WHERE NOT lower_inc(thing_history_translations.history_valid)
      AND thing_history_translations.history_valid != 'empty'
    SQL
  end

  def down
  end
end

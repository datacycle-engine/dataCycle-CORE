# frozen_string_literal: true

class LastFixForHistories < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    # execute <<-SQL.squish
    #   WITH sub_subquery2 AS (
    #     SELECT
    #       t2.thing_id,
    #       t1.locale,
    #       min(LOWER(t1.history_valid)) AS lower_valid
    #     FROM
    #       thing_history_translations t1
    #       INNER JOIN thing_histories t2 ON t2.id = t1.thing_history_id
    #     GROUP BY
    #       t2.thing_id,
    #       t1.locale
    #   ),
    #   subquery2 AS (
    #     SELECT
    #       h1.id
    #     FROM
    #       thing_history_translations AS h1
    #       INNER JOIN thing_histories h2 ON h2.id = h1.thing_history_id
    #       JOIN sub_subquery2 AS s2 ON h2.thing_id = s2.thing_id
    #         AND h1.locale = s2.locale
    #         AND s2.lower_valid = LOWER(h1.history_valid))
    #     UPDATE
    #       thing_history_translations
    #     SET
    #       history_valid = tstzrange(LEAST (thing_history_translations.created_at::timestamp with time zone, UPPER(thing_history_translations.history_valid)), UPPER(thing_history_translations.history_valid), '[)')
    #     FROM
    #       subquery2
    #   WHERE
    #     thing_history_translations.id = subquery2.id
    #     AND (thing_history_translations.created_at < UPPER(thing_history_translations.history_valid)
    #       OR upper_inf(thing_history_translations.history_valid));
    # SQL
  end

  def down
  end
end

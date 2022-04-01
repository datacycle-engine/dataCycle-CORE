# frozen_string_literal: true

class UpdateOldHistories < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL.squish
      WITH sub_subquery2 AS (
        SELECT
          t2.thing_id,
          t1.locale,
          max(UPPER(t1.history_valid)) AS upper_valid
        FROM
          thing_history_translations t1
          INNER JOIN thing_histories t2 ON t2.id = t1.thing_history_id
        GROUP BY
          t2.thing_id,
          t1.locale
      ),
      subquery2 AS (
        SELECT
          h1.id
        FROM
          thing_history_translations AS h1
          INNER JOIN thing_histories h2 ON h2.id = h1.thing_history_id
          JOIN sub_subquery2 AS s2 ON h2.thing_id = s2.thing_id
            AND h1.locale = s2.locale
            AND s2.upper_valid = UPPER(h1.history_valid))
        UPDATE
          thing_history_translations
        SET
          history_valid = tstzrange(lower(thing_history_translations.history_valid), NULL, '[)')
        FROM
          subquery2
      WHERE
        thing_history_translations.id = subquery2.id;

      WITH sub_subquery3 AS (
        SELECT
          t2.thing_id,
          t1.locale,
          max(UPPER(t1.history_valid)) AS upper_valid
        FROM
          thing_history_translations t1
          INNER JOIN thing_histories t2 ON t2.id = t1.thing_history_id
        GROUP BY
          t2.thing_id,
          t1.locale
      ),
      subquery3 AS (
        SELECT
          h2.id
        FROM
          thing_history_translations AS h1
          INNER JOIN thing_histories h2 ON h2.id = h1.thing_history_id
          JOIN sub_subquery3 AS s2 ON h2.thing_id = s2.thing_id
            AND h1.locale = s2.locale
            AND s2.upper_valid = UPPER(h1.history_valid))
        UPDATE
          content_content_histories
        SET
          history_valid = tstzrange(lower(content_content_histories.history_valid), NULL, '[)')
        FROM
          subquery3
      WHERE
        content_content_histories.content_a_history_id = subquery3.id;
    SQL
  end

  def down
  end
end

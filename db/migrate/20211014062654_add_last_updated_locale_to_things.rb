# frozen_string_literal: true

class AddLastUpdatedLocaleToThings < ActiveRecord::Migration[5.2]
  def up
    add_column :things, :last_updated_locale, :string
    add_column :thing_histories, :last_updated_locale, :string

    execute <<~SQL.squish
      WITH subquery1 AS (
        SELECT DISTINCT ON (thing_id)
          thing_id,
          locale
        FROM
          thing_translations t2
        ORDER BY
          thing_id ASC,
          updated_at DESC)
      UPDATE
        things
      SET
        last_updated_locale = subquery1.locale
      FROM
        subquery1
      WHERE
        things.id = subquery1.thing_id;

      UPDATE
        things
      SET
        last_updated_locale = 'de'
      WHERE
        last_updated_locale IS NULL;

      WITH subquery2 AS (
        SELECT
          t4.id
        FROM
          thing_history_translations t4
          INNER JOIN thing_histories t3 ON t3.id = t4.thing_history_id
        WHERE
          t4.id = (
            SELECT
              t2.id
            FROM
              thing_history_translations t2
              INNER JOIN thing_histories t1 ON t1.id = t2.thing_history_id
            WHERE
              t3.thing_id = t1.thing_id
              AND t4.locale = t2.locale
            ORDER BY
              UPPER(t2.history_valid) DESC
            LIMIT 1))
      UPDATE
        thing_history_translations
      SET
        history_valid = tstzrange(lower(thing_history_translations.history_valid), NULL, '[)')
      FROM
        subquery2
      WHERE
        thing_history_translations.id = subquery2.id;

      WITH subquery3 AS (
        SELECT
          t3.id
        FROM
          thing_history_translations t4
          INNER JOIN thing_histories t3 ON t3.id = t4.thing_history_id
        WHERE
          t4.id = (
            SELECT
              t2.id
            FROM
              thing_history_translations t2
              INNER JOIN thing_histories t1 ON t1.id = t2.thing_history_id
            WHERE
              t3.thing_id = t1.thing_id
              AND t4.locale = t2.locale
            ORDER BY
              UPPER(t2.history_valid) DESC
            LIMIT 1))
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
    remove_column :things, :last_updated_locale
    remove_column :thing_histories, :last_updated_locale
  end
end

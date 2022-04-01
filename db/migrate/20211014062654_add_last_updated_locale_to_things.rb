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
    SQL
  end

  def down
    remove_column :things, :last_updated_locale
    remove_column :thing_histories, :last_updated_locale
  end
end

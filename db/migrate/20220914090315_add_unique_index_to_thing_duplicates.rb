# frozen_string_literal: true

class AddUniqueIndexToThingDuplicates < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DELETE FROM
        thing_duplicates t1
      WHERE
        EXISTS (
          SELECT
            1
          FROM
            thing_duplicates t2
          WHERE
            t1.id != t2.id
            AND LEAST(t1.thing_id, t1.thing_duplicate_id) = LEAST(t2.thing_id, t2.thing_duplicate_id)
            AND GREATEST(t1.thing_id, t1.thing_duplicate_id) = GREATEST(t2.thing_id, t2.thing_duplicate_id)
        );

      CREATE UNIQUE INDEX IF NOT EXISTS unique_thing_duplicate_idx ON thing_duplicates (
        LEAST(thing_id, thing_duplicate_id),
        GREATEST(thing_id, thing_duplicate_id)
      );
    SQL
  end

  def down
    remove_index :thing_duplicates, name: :unique_thing_duplicate_idx
  end
end

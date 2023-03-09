# frozen_string_literal: true

class AddSlugToWatchListAndStoredSearch < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    # regex expressions need to be escaped in execute blocks ('-\\d*$')
    execute <<-SQL.squish
      CREATE TABLE collection_configurations (
        id UUID NOT NULL PRIMARY KEY,
        watch_list_id UUID,
        stored_filter_id UUID,
        slug VARCHAR UNIQUE,
        CONSTRAINT fk_collection_watch_list FOREIGN KEY(watch_list_id) REFERENCES watch_lists (id) ON DELETE CASCADE,
        CONSTRAINT fk_collection_stored_filter FOREIGN KEY(stored_filter_id) REFERENCES stored_filters (id) ON DELETE CASCADE
      );

      CREATE INDEX collection_configurations_watch_list_id_idx ON collection_configurations USING btree (watch_list_id);
      CREATE INDEX collection_configurations_stored_filter_id_idx ON collection_configurations USING btree (stored_filter_id);

      CREATE OR REPLACE FUNCTION generate_unique_collection_slug(old_slug VARCHAR, OUT new_slug VARCHAR) LANGUAGE PLPGSQL AS $$ BEGIN WITH input AS (
          SELECT old_slug::VARCHAR AS slug,
          regexp_replace(old_slug, '-\\d*$', '')::VARCHAR || '-' AS base_slug
        )
      SELECT i.slug
      FROM input i
        LEFT JOIN collection_configurations a USING (slug)
      WHERE a.slug IS NULL
      UNION ALL
      (
        SELECT i.base_slug || COALESCE(
            right(a.slug, length(i.base_slug) * -1)::int + 1,
            1
          )
        FROM input i
          LEFT JOIN collection_configurations a ON a.slug LIKE (i.base_slug || '%')
          AND right(a.slug, length(i.base_slug) * -1) ~ '^\\d+$'
        ORDER BY right(a.slug, length(i.base_slug) * -1)::int DESC
      )
      LIMIT 1 INTO new_slug;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_collection_slug_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN NEW.slug :=  generate_unique_collection_slug (NEW.slug);

      RETURN NEW;

      END;

      $$;

      CREATE TRIGGER generate_collection_slug_trigger BEFORE
      INSERT ON collection_configurations FOR EACH ROW EXECUTE FUNCTION generate_collection_slug_trigger ();

      CREATE TRIGGER update_collection_slug_trigger BEFORE
      UPDATE OF slug ON collection_configurations FOR EACH ROW
        WHEN (
          OLD.slug IS DISTINCT
          FROM NEW.slug
        ) EXECUTE FUNCTION generate_collection_slug_trigger ();

      CREATE OR REPLACE FUNCTION generate_collection_id_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN NEW.id := COALESCE(NEW.watch_list_id, NEW.stored_filter_id);

      RETURN NEW;

      END;

      $$;

      CREATE TRIGGER generate_collection_id_trigger BEFORE
      INSERT ON collection_configurations FOR EACH ROW EXECUTE FUNCTION generate_collection_id_trigger ();

      CREATE TRIGGER update_collection_id_trigger BEFORE
      UPDATE OF watch_list_id,
        stored_filter_id ON collection_configurations FOR EACH ROW
        WHEN (
          (
            OLD.watch_list_id IS DISTINCT
            FROM NEW.watch_list_id
          )
          OR (
            OLD.stored_filter_id IS DISTINCT
            FROM NEW.stored_filter_id
          )
        ) EXECUTE FUNCTION generate_collection_id_trigger ();
    SQL

    execute <<-SQL.squish
      VACUUM ANALYZE collection_configurations;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS update_collection_id_trigger ON collection_configurations;
      DROP TRIGGER IF EXISTS generate_collection_id_trigger ON collection_configurations;
      DROP FUNCTION IF EXISTS generate_collection_id_trigger;

      DROP TRIGGER IF EXISTS update_collection_slug_trigger ON collection_configurations;
      DROP TRIGGER IF EXISTS generate_collection_slug_trigger ON collection_configurations;
      DROP FUNCTION IF EXISTS generate_collection_slug_trigger;

      DROP FUNCTION IF EXISTS generate_unique_collection_slug;

      DROP TABLE collection_configurations;
    SQL
  end
end

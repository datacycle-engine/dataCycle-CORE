# frozen_string_literal: true

class RefactorContentContentLinkTriggers < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP INDEX IF EXISTS index_contents_a_b;

      CREATE INDEX IF NOT EXISTS index_content_content_links_on_contents_a_b ON content_content_links USING btree (content_a_id, content_b_id);

      ALTER TABLE content_content_links
      ADD COLUMN content_content_id uuid DEFAULT uuid_generate_v4() NOT NULL,
        ADD COLUMN relation character varying,
        ADD CONSTRAINT fk_content_content_links_content_contents FOREIGN KEY (content_content_id) REFERENCES content_contents (id) ON DELETE CASCADE ON UPDATE CASCADE NOT VALID,
        ADD CONSTRAINT content_content_links_uq_constraint UNIQUE (content_content_id, content_a_id, content_b_id);

      DROP TRIGGER IF EXISTS delete_content_content_links_trigger ON content_contents;

      DROP FUNCTION IF EXISTS delete_content_content_links_trigger;

      DROP FUNCTION IF EXISTS delete_content_content_links;

      DROP TRIGGER IF EXISTS generate_content_content_links_trigger ON content_contents;

      DROP TRIGGER IF EXISTS update_content_content_links_trigger ON content_contents;

      DROP FUNCTION IF EXISTS generate_content_content_links_trigger;

      DROP FUNCTION IF EXISTS generate_content_content_links;

      CREATE OR REPLACE FUNCTION generate_content_content_links(content_content_ids uuid[]) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO content_content_links (
          content_a_id,
          content_b_id,
          content_content_id,
          relation
        )
      SELECT content_contents.content_a_id AS "content_a_id",
        content_contents.content_b_id AS "content_b_id",
        content_contents.id AS "content_content_id",
        content_contents.relation_a AS "relation"
      FROM content_contents
      WHERE content_contents.id = ANY(content_content_ids)
      UNION
      SELECT content_contents.content_b_id AS "content_a_id",
        content_contents.content_a_id AS "content_b_id",
        content_contents.id AS "content_content_id",
        content_contents.relation_b AS "relation"
      FROM content_contents
      WHERE content_contents.id = ANY(content_content_ids)
        AND content_contents.relation_b IS NOT NULL ON CONFLICT (content_content_id, content_a_id, content_b_id) DO
        UPDATE
        SET relation = EXCLUDED.relation;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_content_content_links_trigger() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_content_content_links (
          ARRAY_AGG(DISTINCT inserted_content_contents.id)
        )
      FROM (
          SELECT DISTINCT new_content_contents.id
          FROM new_content_contents
        ) "inserted_content_contents";

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER generate_content_content_links_trigger
      AFTER
      INSERT ON content_contents REFERENCING NEW TABLE AS new_content_contents FOR EACH STATEMENT EXECUTE FUNCTION generate_content_content_links_trigger();

      CREATE OR REPLACE FUNCTION generate_content_content_links_trigger2() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_content_content_links (
          ARRAY_AGG(DISTINCT updated_content_contents.id)
        )
      FROM (
          SELECT DISTINCT old_content_contents.id
          FROM old_content_contents
            INNER JOIN new_content_contents ON old_content_contents.id = new_content_contents.id
          WHERE old_content_contents.content_a_id IS DISTINCT
          FROM new_content_contents.content_a_id
            OR old_content_contents.relation_a IS DISTINCT
          FROM new_content_contents.relation_a
            OR old_content_contents.content_b_id IS DISTINCT
          FROM new_content_contents.content_b_id
            OR old_content_contents.relation_b IS DISTINCT
          FROM new_content_contents.relation_b
        ) "updated_content_contents";

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER update_content_content_links_trigger
      AFTER
      UPDATE ON content_contents REFERENCING NEW TABLE AS new_content_contents old TABLE AS old_content_contents FOR EACH STATEMENT EXECUTE FUNCTION generate_content_content_links_trigger2();
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE content_content_links DROP CONSTRAINT fk_content_content_links_content_contents,
        DROP COLUMN content_content_id,
        DROP COLUMN relation;

      TRUNCATE content_content_links;

      CREATE UNIQUE INDEX IF NOT EXISTS index_contents_a_b ON content_content_links USING btree (content_a_id, content_b_id);

      DROP INDEX IF EXISTS index_content_content_links_on_contents_a_b;

      CREATE OR REPLACE FUNCTION delete_content_content_links(a uuid, b uuid) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM content_content_links
      WHERE content_a_id = a
        AND content_b_id = b;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION delete_content_content_links_trigger() RETURNS TRIGGER LANGUAGE plpgsql AS $$
      DECLARE a_b INTEGER;

      DECLARE b_a INTEGER;

      BEGIN a_b := (
        SELECT COUNT(*)
        FROM content_contents
        WHERE (
            content_a_id = OLD.content_a_id
            AND content_b_id = OLD.content_b_id
          )
          OR (
            content_a_id = OLD.content_b_id
            AND content_b_id = OLD.content_a_id
            AND relation_b IS NOT NULL
          )
      );

      b_a := (
        SELECT COUNT(*)
        FROM content_contents
        WHERE (
            content_a_id = OLD.content_a_id
            AND content_b_id = OLD.content_b_id
            AND OLD.relation_b IS NOT NULL
          )
          OR (
            content_a_id = OLD.content_b_id
            AND content_b_id = OLD.content_a_id
          )
      );

      IF a_b = 1 THEN PERFORM delete_content_content_links(OLD.content_a_id, OLD.content_b_id);

      END IF;

      IF b_a = 1 THEN PERFORM delete_content_content_links(OLD.content_b_id, OLD.content_a_id);

      END IF;

      RETURN OLD;

      END;

      $$;

      DROP TRIGGER IF EXISTS delete_content_content_links_trigger ON content_contents;

      CREATE TRIGGER delete_content_content_links_trigger BEFORE DELETE ON content_contents FOR EACH ROW EXECUTE FUNCTION delete_content_content_links_trigger();

      DROP TRIGGER IF EXISTS generate_content_content_links_trigger ON content_contents;

      DROP TRIGGER IF EXISTS update_content_content_links_trigger ON content_contents;

      DROP FUNCTION IF EXISTS generate_content_content_links_trigger;

      DROP FUNCTION IF EXISTS generate_content_content_links;

      CREATE OR REPLACE FUNCTION generate_content_content_links(a uuid, b uuid) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO content_content_links (content_a_id, content_b_id)
      SELECT content_a_id,
        content_b_id
      FROM content_contents
      WHERE content_a_id = a
        AND content_b_id = b ON CONFLICT DO NOTHING;

      INSERT INTO content_content_links (content_a_id, content_b_id)
      SELECT content_b_id,
        content_a_id
      FROM content_contents
      WHERE content_a_id = a
        AND content_b_id = b
        AND relation_b IS NOT NULL ON CONFLICT DO NOTHING;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_content_content_links_trigger() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_content_content_links(NEW.content_a_id, NEW.content_b_id);

      RETURN NEW;

      END;

      $$;

      CREATE TRIGGER generate_content_content_links_trigger
      AFTER
      INSERT ON content_contents FOR EACH ROW EXECUTE FUNCTION generate_content_content_links_trigger();

      CREATE TRIGGER update_content_content_links_trigger
      AFTER
      UPDATE OF content_a_id,
        content_b_id,
        relation_b ON content_contents FOR EACH ROW
        WHEN (
          (
            (
              old.content_a_id IS DISTINCT
              FROM new.content_a_id
            )
            OR (
              old.content_b_id IS DISTINCT
              FROM new.content_b_id
            )
            OR (
              (old.relation_b)::text IS DISTINCT
              FROM (new.relation_b)::text
            )
          )
        ) EXECUTE FUNCTION generate_content_content_links_trigger();

      SELECT generate_content_content_links(content_contents.content_a_id, content_contents.content_b_id) FROM content_contents;
    SQL
  end
end

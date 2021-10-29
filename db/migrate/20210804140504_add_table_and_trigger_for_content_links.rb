# frozen_string_literal: true

class AddTableAndTriggerForContentLinks < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      CREATE TABLE content_content_links (
        content_a_id UUID,
        content_b_id UUID
      );
      CREATE UNIQUE INDEX IF NOT EXISTS index_contents_a_b ON content_content_links (content_a_id, content_b_id);

      CREATE OR REPLACE FUNCTION generate_content_content_links(a UUID, b UUID) RETURNS UUID[] LANGUAGE PLPGSQL AS $$
      BEGIN
        INSERT INTO content_content_links (content_a_id, content_b_id)
          SELECT content_a_id, content_b_id
          FROM content_contents
          WHERE content_a_id = a
          AND content_b_id = b
        ON CONFLICT DO NOTHING;

        INSERT INTO content_content_links (content_a_id, content_b_id)
          SELECT content_b_id, content_a_id
          FROM content_contents
          WHERE content_a_id = a
          AND content_b_id = b
          AND relation_b IS NOT NULL
        ON CONFLICT DO NOTHING;

        RETURN ARRAY[a, b];
      END;$$;

      CREATE OR REPLACE FUNCTION generate_content_content_links_trigger() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
      BEGIN
        PERFORM generate_content_content_links(NEW.content_a_id, NEW.content_b_id);

        RETURN NEW;
      END;$$;

      CREATE TRIGGER generate_content_content_links_trigger
        AFTER INSERT OR UPDATE
        ON content_contents
        FOR EACH ROW EXECUTE FUNCTION generate_content_content_links_trigger();


      CREATE OR REPLACE FUNCTION delete_content_content_links(a UUID, b UUID) RETURNS UUID[] LANGUAGE PLPGSQL AS $$
      BEGIN
        DELETE FROM content_content_links
          WHERE content_a_id = a
          AND content_b_id = b;

        RETURN ARRAY[a, b];
      END;$$;

      CREATE OR REPLACE FUNCTION delete_content_content_links_trigger() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
        DECLARE a_b INTEGER;
        DECLARE b_a INTEGER;
      BEGIN
        a_b := (
          SELECT COUNT(*) FROM content_contents
          WHERE
            ( content_a_id = OLD.content_a_id AND content_b_id = OLD.content_b_id )
          OR
            (
              content_a_id = OLD.content_b_id
              AND content_b_id = OLD.content_a_id
              AND relation_b IS NOT NULL
            )
        );

        b_a := (
          SELECT COUNT(*) FROM content_contents
          WHERE
            (
              content_a_id = OLD.content_a_id
              AND content_b_id = OLD.content_b_id
              AND OLD.relation_b IS NOT NULL
            )
          OR
            ( content_a_id = OLD.content_b_id AND content_b_id = OLD.content_a_id )
        );

        IF a_b = 1 THEN
          PERFORM delete_content_content_links(OLD.content_a_id, OLD.content_b_id);
        END IF;

        IF b_a = 1 THEN
          PERFORM delete_content_content_links(OLD.content_b_id, OLD.content_a_id);
        END IF;

        RETURN OLD;
      END;$$;

      CREATE TRIGGER delete_content_content_links_trigger
        BEFORE DELETE
        ON content_contents
        FOR EACH ROW EXECUTE FUNCTION delete_content_content_links_trigger();

      INSERT INTO content_content_links (content_a_id, content_b_id)
        SELECT content_a_id, content_b_id
        FROM content_contents
      ON CONFLICT DO NOTHING;
      INSERT INTO content_content_links (content_a_id, content_b_id)
        SELECT content_b_id, content_a_id
        FROM content_contents
        WHERE relation_b IS NOT NULL
      ON CONFLICT DO NOTHING;
    SQL
    ActiveRecord::Base.connection.execute('VACUUM ANALYZE content_content_links')
  end

  def down
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS delete_content_content_links_trigger ON content_contents;
      DROP FUNCTION IF EXISTS delete_content_content_links;
      DROP TRIGGER IF EXISTS generate_content_content_links_trigger ON content_contents;
      DROP FUNCTION IF EXISTS generate_content_content_links;
      DROP INDEX IF EXISTS index_contents_a_b;
      DROP TABLE IF EXISTS content_content_links;
    SQL
  end
end

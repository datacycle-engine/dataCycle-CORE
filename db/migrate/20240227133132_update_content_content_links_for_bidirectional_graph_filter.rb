# frozen_string_literal: true

class UpdateContentContentLinksForBidirectionalGraphFilter < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
            DROP FUNCTION IF EXISTS generate_content_content_links;

            CREATE OR REPLACE FUNCTION generate_content_content_links(content_content_ids uuid[]) RETURNS VOID LANGUAGE plpgsql AS $$ BEGIN
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
              ON CONFLICT (content_content_id, content_a_id, content_b_id, relation) DO
              NOTHING;

            RETURN;

            END;

            $$;

      SELECT generate_content_content_links( array(select id from content_contents) );

    SQL
  end

  def down
    execute <<-SQL.squish

    TRUNCATE content_content_links;

    DROP FUNCTION generate_content_content_links(uuid[]);

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
        AND content_contents.relation_b IS NOT NULL ON CONFLICT (content_content_id, content_a_id, content_b_id, relation) DO
        NOTHING;

      RETURN;

      END;

      $$;


    SELECT generate_content_content_links( array(select id from content_contents) );

    SQL
  end
end

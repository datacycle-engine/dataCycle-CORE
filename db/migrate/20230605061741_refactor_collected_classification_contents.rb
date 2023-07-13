# frozen_string_literal: true

class RefactorCollectedClassificationContents < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP TABLE collected_classification_contents;

      CREATE TABLE collected_classification_contents (
        thing_id uuid NOT NULL,
        classification_alias_id uuid NOT NULL,
        classification_tree_label_id uuid NOT NULL,
        direct boolean DEFAULT FALSE,
        PRIMARY KEY (thing_id, classification_alias_id),
        CONSTRAINT fk_things FOREIGN KEY(thing_id) REFERENCES things(id) ON DELETE CASCADE,
        CONSTRAINT fk_classification_aliases FOREIGN KEY(classification_alias_id) REFERENCES classification_aliases(id) ON DELETE CASCADE,
        CONSTRAINT fk_classification_tree_labels FOREIGN KEY(classification_tree_label_id) REFERENCES classification_tree_labels(id) ON DELETE CASCADE
      );

      CREATE INDEX ccc_ca_id_t_id_idx ON collected_classification_contents USING btree (classification_alias_id, thing_id, direct);
      CREATE INDEX ccc_ctl_id_t_id_idx ON collected_classification_contents USING btree (classification_tree_label_id, thing_id, direct);

      CREATE OR REPLACE FUNCTION generate_collected_cl_content_relations_transitive(
          content_ids uuid [],
          excluded_classification_ids uuid []
        ) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM collected_classification_contents
      WHERE thing_id IN (
          SELECT cccr.thing_id
          FROM collected_classification_contents cccr
          WHERE cccr.thing_id = ANY (content_ids)
          ORDER BY cccr.thing_id ASC FOR
          UPDATE SKIP LOCKED
        );

      WITH direct_classification_content_relations AS (
        SELECT DISTINCT ON (
            classification_contents.content_data_id,
            classification_aliases.id
          ) classification_contents.content_data_id "thing_id",
          classification_aliases.id "classification_alias_id",
          classification_trees.classification_tree_label_id,
          TRUE "direct"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_aliases ON classification_aliases.id = classification_groups.classification_alias_id
          JOIN classification_trees ON classification_trees.classification_alias_id = classification_aliases.id
          AND classification_trees.deleted_at IS NULL
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
      ),
      full_classification_content_relations AS (
        SELECT DISTINCT ON (classification_contents.content_data_id, a.e) classification_contents.content_data_id "thing_id",
          a.e "classification_alias_id",
          classification_trees.classification_tree_label_id,
          FALSE "direct"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = classification_alias_paths_transitive.classification_alias_id
          JOIN classification_trees ON classification_trees.classification_alias_id = ANY (
            classification_alias_paths_transitive.full_path_ids
          )
          AND classification_trees.deleted_at IS NULL
          INNER JOIN LATERAL UNNEST(
            classification_alias_paths_transitive.full_path_ids
          ) AS a (e) ON a.e = classification_trees.classification_alias_id
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
          AND NOT EXISTS (
            SELECT 1
            FROM direct_classification_content_relations dccr
            WHERE dccr.thing_id = classification_contents.content_data_id
              AND dccr.classification_alias_id = a.e
          )
      )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          direct
        )
      SELECT direct_classification_content_relations.thing_id,
        direct_classification_content_relations.classification_alias_id,
        direct_classification_content_relations.classification_tree_label_id,
        direct_classification_content_relations.direct
      FROM direct_classification_content_relations
      UNION
      SELECT full_classification_content_relations.thing_id,
        full_classification_content_relations.classification_alias_id,
        full_classification_content_relations.classification_tree_label_id,
        full_classification_content_relations.direct
      FROM full_classification_content_relations ON CONFLICT DO NOTHING;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations(
          content_ids uuid [],
          excluded_classification_ids uuid []
        ) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM collected_classification_contents
      WHERE thing_id IN (
          SELECT cccr.thing_id
          FROM collected_classification_contents cccr
          WHERE cccr.thing_id = ANY (content_ids)
          ORDER BY cccr.thing_id ASC FOR
          UPDATE SKIP LOCKED
        );

      WITH direct_classification_content_relations AS (
        SELECT DISTINCT ON (
            classification_contents.content_data_id,
            classification_groups.classification_alias_id
          ) classification_contents.content_data_id "thing_id",
          classification_groups.classification_alias_id,
          classification_trees.classification_tree_label_id,
          TRUE "direct"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id
          AND classification_trees.deleted_at IS NULL
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
      ),
      full_classification_content_relations AS (
        SELECT DISTINCT ON (classification_contents.content_data_id, a.e) classification_contents.content_data_id "thing_id",
          a.e "classification_alias_id",
          classification_trees.classification_tree_label_id "classification_tree_label_id",
          FALSE "direct"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
          JOIN classification_trees ON classification_trees.classification_alias_id = ANY (classification_alias_paths.full_path_ids)
          AND classification_trees.deleted_at IS NULL
          CROSS JOIN LATERAL UNNEST(classification_alias_paths.full_path_ids) AS a (e)
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
          AND NOT EXISTS (
            SELECT 1
            FROM direct_classification_content_relations dccr
            WHERE dccr.thing_id = classification_contents.content_data_id
              AND dccr.classification_alias_id = a.e
          )
      )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          direct
        )
      SELECT direct_classification_content_relations.thing_id,
        direct_classification_content_relations.classification_alias_id,
        direct_classification_content_relations.classification_tree_label_id,
        direct_classification_content_relations.direct
      FROM direct_classification_content_relations
      UNION
      SELECT full_classification_content_relations.thing_id,
        full_classification_content_relations.classification_alias_id,
        full_classification_content_relations.classification_tree_label_id,
        full_classification_content_relations.direct
      FROM full_classification_content_relations ON CONFLICT DO NOTHING;

      RETURN;

      END;

      $$;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TABLE collected_classification_contents;

      CREATE TABLE collected_classification_contents (
        thing_id uuid NOT NULL,
        direct_classification_alias_ids uuid [],
        full_classification_alias_ids uuid [],
        direct_tree_label_ids uuid [],
        full_tree_label_ids uuid [],
        PRIMARY KEY (thing_id),
        CONSTRAINT collected_classification_contents_thing_id_fkey FOREIGN KEY (thing_id) REFERENCES things(id) ON DELETE CASCADE
      );

      CREATE INDEX ccc_direct_classification_alias_ids_idx ON collected_classification_contents USING gin (direct_classification_alias_ids);

      CREATE INDEX ccc_direct_tree_label_ids_idx ON collected_classification_contents USING gin (direct_tree_label_ids);

      CREATE INDEX ccc_full_classification_alias_ids_idx ON collected_classification_contents USING gin (full_classification_alias_ids);

      CREATE INDEX ccc_full_tree_label_ids_idx ON collected_classification_contents USING gin (full_tree_label_ids);

      CREATE OR REPLACE FUNCTION generate_collected_cl_content_relations_transitive(
        content_ids uuid [],
        excluded_classification_ids uuid []
      ) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM collected_classification_contents
      WHERE thing_id IN (
          SELECT cccr.thing_id
          FROM collected_classification_contents cccr
          WHERE cccr.thing_id = ANY (content_ids)
          ORDER BY cccr.thing_id ASC FOR
          UPDATE SKIP LOCKED
        );

      WITH direct_classification_content_relations AS (
        SELECT classification_contents.content_data_id "thing_id",
          ARRAY_AGG(
            DISTINCT classification_groups.classification_alias_id
          ) "direct_alias_ids",
          ARRAY_AGG(
            DISTINCT classification_trees.classification_tree_label_id
          ) "direct_tree_label_ids"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id
          AND classification_trees.deleted_at IS NULL
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
        GROUP BY classification_contents.content_data_id
      ),
      full_classification_content_relations AS (
        SELECT classification_contents.content_data_id "thing_id",
          ARRAY_AGG(DISTINCT a.e) "full_alias_ids",
          ARRAY_AGG(
            DISTINCT classification_trees.classification_tree_label_id
          ) "full_tree_label_ids"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = classification_alias_paths_transitive.classification_alias_id
          JOIN classification_trees ON classification_trees.classification_alias_id = ANY (
            classification_alias_paths_transitive.full_path_ids
          )
          AND classification_trees.deleted_at IS NULL
          CROSS JOIN LATERAL UNNEST(
            classification_alias_paths_transitive.full_path_ids
          ) AS a (e)
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
        GROUP BY classification_contents.content_data_id
      )
      INSERT INTO collected_classification_contents (
          thing_id,
          direct_classification_alias_ids,
          full_classification_alias_ids,
          direct_tree_label_ids,
          full_tree_label_ids
        )
      SELECT direct_classification_content_relations.thing_id,
        direct_classification_content_relations.direct_alias_ids,
        full_classification_content_relations.full_alias_ids,
        direct_classification_content_relations.direct_tree_label_ids,
        full_classification_content_relations.full_tree_label_ids
      FROM direct_classification_content_relations
        JOIN full_classification_content_relations ON full_classification_content_relations.thing_id = direct_classification_content_relations.thing_id ON CONFLICT (thing_id) DO
      UPDATE
      SET direct_classification_alias_ids = EXCLUDED.direct_classification_alias_ids,
        full_classification_alias_ids = EXCLUDED.full_classification_alias_ids,
        direct_tree_label_ids = EXCLUDED.direct_tree_label_ids,
        full_tree_label_ids = EXCLUDED.full_tree_label_ids;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations(
        content_ids uuid [],
        excluded_classification_ids uuid []
      ) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM collected_classification_contents
      WHERE thing_id IN (
          SELECT cccr.thing_id
          FROM collected_classification_contents cccr
          WHERE cccr.thing_id = ANY (content_ids)
          ORDER BY cccr.thing_id ASC FOR
          UPDATE SKIP LOCKED
        );

      WITH direct_classification_content_relations AS (
        SELECT classification_contents.content_data_id "thing_id",
          ARRAY_AGG(
            DISTINCT classification_groups.classification_alias_id
          ) "direct_alias_ids",
          ARRAY_AGG(
            DISTINCT classification_trees.classification_tree_label_id
          ) "direct_tree_label_ids"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id
          AND classification_trees.deleted_at IS NULL
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
        GROUP BY classification_contents.content_data_id
      ),
      full_classification_content_relations AS (
        SELECT classification_contents.content_data_id "thing_id",
          ARRAY_AGG(DISTINCT a.e) "full_alias_ids",
          ARRAY_AGG(
            DISTINCT classification_trees.classification_tree_label_id
          ) "full_tree_label_ids"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
          JOIN classification_trees ON classification_trees.classification_alias_id = ANY (classification_alias_paths.full_path_ids)
          AND classification_trees.deleted_at IS NULL
          CROSS JOIN LATERAL UNNEST(classification_alias_paths.full_path_ids) AS a (e)
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
        GROUP BY classification_contents.content_data_id
      )
      INSERT INTO collected_classification_contents (
          thing_id,
          direct_classification_alias_ids,
          full_classification_alias_ids,
          direct_tree_label_ids,
          full_tree_label_ids
        )
      SELECT direct_classification_content_relations.thing_id,
        direct_classification_content_relations.direct_alias_ids,
        full_classification_content_relations.full_alias_ids,
        direct_classification_content_relations.direct_tree_label_ids,
        full_classification_content_relations.full_tree_label_ids
      FROM direct_classification_content_relations
        JOIN full_classification_content_relations ON full_classification_content_relations.thing_id = direct_classification_content_relations.thing_id ON CONFLICT (thing_id) DO
      UPDATE
      SET direct_classification_alias_ids = EXCLUDED.direct_classification_alias_ids,
        full_classification_alias_ids = EXCLUDED.full_classification_alias_ids,
        direct_tree_label_ids = EXCLUDED.direct_tree_label_ids,
        full_tree_label_ids = EXCLUDED.full_tree_label_ids;

      RETURN;

      END;

      $$;
    SQL
  end
end

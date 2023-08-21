# frozen_string_literal: true

class AddIdColumnToCollectedClassificationContents < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE IF EXISTS collected_classification_contents
      ADD COLUMN id uuid NOT NULL DEFAULT uuid_generate_v4();

      ALTER TABLE IF EXISTS collected_classification_contents DROP CONSTRAINT collected_classification_contents_pkey;

      ALTER TABLE IF EXISTS collected_classification_contents
      ADD PRIMARY KEY (id);

      CREATE UNIQUE INDEX ccc_unique_thing_id_classification_alias_id_idx ON collected_classification_contents(thing_id, classification_alias_id);

      ALTER TABLE classification_alias_paths_transitive
      ADD CONSTRAINT classification_alias_paths_transitive_unique UNIQUE (full_path_ids);

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive (classification_alias_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN IF array_length(classification_alias_ids, 1) > 0 THEN
      WITH RECURSIVE paths(
        id,
        parent_id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types,
        tree_label_id
      ) AS (
        SELECT classification_aliases.id,
          classification_trees.parent_classification_alias_id,
          ARRAY []::uuid [],
          ARRAY [classification_aliases.id],
          ARRAY [classification_aliases.internal_name],
          ARRAY []::text [],
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
        WHERE classification_trees.classification_alias_id = ANY(classification_alias_ids)
        UNION ALL
        SELECT paths.id,
          classification_trees.parent_classification_alias_id,
          ancestor_ids || classification_aliases.id,
          full_path_ids || classification_aliases.id,
          full_path_names || classification_aliases.internal_name,
          ARRAY ['broader'] || paths.link_types,
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN paths ON paths.parent_id = classification_trees.classification_alias_id
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
      ),
      child_paths(
        id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types
      ) AS (
        SELECT paths.id AS id,
          paths.ancestor_ids AS ancestor_ids,
          paths.full_path_ids AS full_path_ids,
          paths.full_path_names || classification_tree_labels.name AS full_path_names,
          paths.link_types AS link_types
        FROM paths
          JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL
        UNION ALL
        SELECT classification_aliases.id AS id,
          (
            classification_alias_links.parent_classification_alias_id || p1.ancestor_ids
          ) AS ancestors_ids,
          (
            classification_aliases.id || p1.full_path_ids
          ) AS full_path_ids,
          (
            classification_aliases.internal_name || p1.full_path_names
          ) AS full_path_names,
          (
            classification_alias_links.link_type || p1.link_types
          ) AS link_types
        FROM classification_alias_links
          JOIN classification_aliases ON classification_aliases.id = classification_alias_links.child_classification_alias_id
          JOIN child_paths p1 ON p1.id = classification_alias_links.parent_classification_alias_id
        WHERE classification_aliases.id <> ALL (p1.full_path_ids)
      ),
      deleted_capt AS (
        DELETE FROM classification_alias_paths_transitive
        WHERE classification_alias_paths_transitive.id IN (
            SELECT capt.id
            FROM classification_alias_paths_transitive capt
            WHERE capt.full_path_ids && classification_alias_ids
              AND NOT EXISTS (
                SELECT 1
                FROM child_paths
                WHERE child_paths.full_path_ids = capt.full_path_ids
              )
            ORDER BY capt.id ASC FOR
            UPDATE SKIP LOCKED
          )
      )
      INSERT INTO classification_alias_paths_transitive (
          classification_alias_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types
        )
      SELECT DISTINCT child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names,
        child_paths.link_types
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO
      UPDATE
      SET full_path_names = EXCLUDED.full_path_names;

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_collected_cl_content_relations_transitive(thing_ids UUID []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN
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
        WHERE classification_contents.content_data_id = ANY(thing_ids)
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
        WHERE classification_contents.content_data_id = ANY(thing_ids)
          AND NOT EXISTS (
            SELECT 1
            FROM direct_classification_content_relations dccr
            WHERE dccr.thing_id = classification_contents.content_data_id
              AND dccr.classification_alias_id = a.e
          )
      ),
      new_collected_classification_contents AS (
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
        FROM full_classification_content_relations
      ),
      deleted_collected_classification_contents AS (
        DELETE FROM collected_classification_contents
        WHERE collected_classification_contents.id IN (
            SELECT ccc.id
            FROM collected_classification_contents ccc
            WHERE ccc.thing_id = ANY(thing_ids)
              AND NOT EXISTS (
                SELECT 1
                FROM new_collected_classification_contents
                WHERE new_collected_classification_contents.thing_id = ccc.thing_id
                  AND new_collected_classification_contents.classification_alias_id = ccc.classification_alias_id
              )
            ORDER BY ccc.id ASC FOR
            UPDATE SKIP LOCKED
          )
      )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          direct
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.direct
      FROM new_collected_classification_contents ON CONFLICT (ccc_unique_thing_id_classification_alias_id_idx) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        direct = EXCLUDED.direct;

      END IF;

      END;

      $$;
    SQL
  end

  def down
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION generate_collected_cl_content_relations_transitive(thing_ids UUID []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN
      DELETE FROM collected_classification_contents
      WHERE collected_classification_contents.thing_id IN (
          SELECT ccc.thing_id
          FROM collected_classification_contents ccc
          WHERE ccc.thing_id = ANY(thing_ids)
          ORDER BY ccc.thing_id ASC FOR
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
        WHERE classification_contents.content_data_id = ANY(thing_ids)
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
        WHERE classification_contents.content_data_id = ANY(thing_ids)
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

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive (classification_alias_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
      DELETE FROM classification_alias_paths_transitive
      WHERE full_path_ids && classification_alias_ids;

      WITH RECURSIVE paths(
        id,
        parent_id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types,
        tree_label_id
      ) AS (
        SELECT classification_aliases.id,
          classification_trees.parent_classification_alias_id,
          ARRAY []::uuid [],
          ARRAY [classification_aliases.id],
          ARRAY [classification_aliases.internal_name],
          ARRAY []::text [],
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
        WHERE classification_trees.classification_alias_id = ANY(classification_alias_ids)
        UNION ALL
        SELECT paths.id,
          classification_trees.parent_classification_alias_id,
          ancestor_ids || classification_aliases.id,
          full_path_ids || classification_aliases.id,
          full_path_names || classification_aliases.internal_name,
          ARRAY ['broader'] || paths.link_types,
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN paths ON paths.parent_id = classification_trees.classification_alias_id
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
      ),
      child_paths(
        id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types
      ) AS (
        SELECT paths.id AS id,
          paths.ancestor_ids AS ancestor_ids,
          paths.full_path_ids AS full_path_ids,
          paths.full_path_names || classification_tree_labels.name AS full_path_names,
          paths.link_types AS link_types
        FROM paths
          JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL
        UNION ALL
        SELECT classification_aliases.id AS id,
          (
            classification_alias_links.parent_classification_alias_id || p1.ancestor_ids
          ) AS ancestors_ids,
          (
            classification_aliases.id || p1.full_path_ids
          ) AS full_path_ids,
          (
            classification_aliases.internal_name || p1.full_path_names
          ) AS full_path_names,
          (
            classification_alias_links.link_type || p1.link_types
          ) AS link_types
        FROM classification_alias_links
          JOIN classification_aliases ON classification_aliases.id = classification_alias_links.child_classification_alias_id
          JOIN child_paths p1 ON p1.id = classification_alias_links.parent_classification_alias_id
        WHERE classification_aliases.id <> ALL (p1.full_path_ids)
      )
      INSERT INTO classification_alias_paths_transitive (
          classification_alias_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types
        )
      SELECT DISTINCT child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names,
        child_paths.link_types
      FROM child_paths;

      RETURN;

      END;

      $$;

      ALTER TABLE classification_alias_paths_transitive
      DROP CONSTRAINT classification_alias_paths_transitive_unique;

      DROP INDEX ccc_unique_thing_id_classification_alias_id_idx;

      ALTER TABLE IF EXISTS collected_classification_contents DROP CONSTRAINT collected_classification_contents_pkey;

      ALTER TABLE IF EXISTS collected_classification_contents
      ADD PRIMARY KEY (thing_id, classification_alias_id);

      ALTER TABLE IF EXISTS collected_classification_contents DROP COLUMN id;
    SQL
  end
end

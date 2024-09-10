# frozen_string_literal: true

class FixFunctionGenerateCollectedClContentRelationsTransitive < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH direct_classification_content_relations AS (
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
      FROM new_collected_classification_contents ON CONFLICT (thing_id, classification_alias_id) DO
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
      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH direct_classification_content_relations AS (
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
end

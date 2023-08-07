# frozen_string_literal: true

class RefactorGcclcRelationsTransitive < ActiveRecord::Migration[6.1]
  def up
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

      CREATE OR REPLACE FUNCTION delete_ccc_relations_transitive_trigger_2() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (
          array_agg(
            collected_classification_content_relations_alias.content_data_id
          )
        )
      FROM (
          SELECT DISTINCT classification_contents.content_data_id
          FROM old_classification_alias_paths_transitive
            INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY (
              old_classification_alias_paths_transitive.full_path_ids
            )
            AND classification_groups.deleted_at IS NULL
            INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id
        ) "collected_classification_content_relations_alias";

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_ccc_relations_transitive_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (
          array_agg(
            collected_classification_content_relations_alias.content_data_id
          )
        )
      FROM (
          SELECT DISTINCT classification_contents.content_data_id
          FROM new_classification_alias_paths_transitive
            INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY (
              new_classification_alias_paths_transitive.full_path_ids
            )
            AND classification_groups.deleted_at IS NULL
            INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id
        ) "collected_classification_content_relations_alias";

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_ccc_relations_transitive_trigger_2() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (ARRAY [NEW.content_data_id]::UUID []);

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION delete_ccc_relations_transitive_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_collected_cl_content_relations_transitive (ARRAY [OLD.content_data_id]::UUID []);

      RETURN NULL;

      END;

      $$;
    SQL
  end

  def down
  end
end

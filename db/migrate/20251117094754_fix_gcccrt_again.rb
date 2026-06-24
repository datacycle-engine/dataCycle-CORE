# frozen_string_literal: true

class FixGcccrtAgain < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH full_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_contents.relation,
              c2.id
            ) classification_contents.content_data_id "thing_id",
            c2.id "classification_alias_id",
            c2.concept_scheme_id "classification_tree_label_id",
            concepts.id = c2.id "direct",
            classification_contents.relation,
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              concepts.id,
              c2.concept_scheme_id
              ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
            ) AS "row_number"
          FROM classification_contents
            JOIN concepts ON concepts.classification_id = classification_contents.classification_id
            JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id
            JOIN concepts c2 ON c2.id = ANY (
              classification_alias_paths_transitive.full_path_ids
            )
            JOIN classification_alias_paths cap ON cap.id = c2.id
          WHERE classification_contents.content_data_id = ANY (thing_ids)
          ORDER BY classification_contents.content_data_id,
            classification_contents.relation,
            c2.id,
            "direct" DESC,
            "row_number"
        ),
        new_collected_classification_contents AS (
          SELECT full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            CASE
              WHEN full_classification_content_relations.direct THEN 'direct'
              WHEN full_classification_content_relations.row_number > 1 THEN 'broader'
              ELSE 'related'
            END AS "link_type",
            full_classification_content_relations.relation
          FROM full_classification_content_relations
        ),
        deleted_collected_classification_contents AS (
          DELETE FROM collected_classification_contents
          WHERE collected_classification_contents.thing_id = ANY(thing_ids)
            AND NOT EXISTS (
              SELECT 1
              FROM new_collected_classification_contents
              WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id
                AND new_collected_classification_contents.relation = collected_classification_contents.relation
                AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id
            )
        )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          link_type,
          relation
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.link_type,
        new_collected_classification_contents.relation
      FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type;

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_from_ca_ids_transitive(ca_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(ca_ids, 1) > 0 THEN WITH full_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_contents.relation,
              c2.id
            ) classification_contents.content_data_id "thing_id",
            c2.id "classification_alias_id",
            c2.concept_scheme_id "classification_tree_label_id",
            concepts.id = c2.id "direct",
            classification_contents.relation,
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              concepts.id,
              c2.concept_scheme_id
              ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
            ) AS "row_number"
          FROM classification_contents
            JOIN concepts ON concepts.classification_id = classification_contents.classification_id
            JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id
            JOIN concepts c2 ON c2.id = ANY (
              classification_alias_paths_transitive.full_path_ids
            )
            JOIN classification_alias_paths cap ON cap.id = c2.id
          WHERE cap.full_path_ids && ca_ids
          ORDER BY classification_contents.content_data_id,
            classification_contents.relation,
            c2.id,
            "direct" DESC,
            "row_number"
        ),
        new_collected_classification_contents AS (
          SELECT full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            CASE
              WHEN full_classification_content_relations.direct THEN 'direct'
              WHEN full_classification_content_relations.row_number > 1 THEN 'broader'
              ELSE 'related'
            END AS "link_type",
            full_classification_content_relations.relation
          FROM full_classification_content_relations
          WHERE full_classification_content_relations.classification_alias_id = ANY(ca_ids)
        ),
        deleted_collected_classification_contents AS (
          DELETE FROM collected_classification_contents
          WHERE collected_classification_contents.classification_alias_id = ANY(ca_ids)
            AND NOT EXISTS (
              SELECT 1
              FROM new_collected_classification_contents
              WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id
                AND new_collected_classification_contents.relation = collected_classification_contents.relation
                AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id
            )
        )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          link_type,
          relation
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.link_type,
        new_collected_classification_contents.relation
      FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type;

      END IF;

      END;

      $$;
    SQL
  end

  def down
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH full_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_contents.relation,
              c2.id
            ) classification_contents.content_data_id "thing_id",
            c2.id "classification_alias_id",
            c2.concept_scheme_id "classification_tree_label_id",
            concepts.id = c2.id "direct",
            classification_contents.relation,
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              classification_alias_paths_transitive.id,
              c2.concept_scheme_id
              ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
            ) AS "row_number"
          FROM classification_contents
            JOIN concepts ON concepts.classification_id = classification_contents.classification_id
            JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id
            JOIN concepts c2 ON c2.id = ANY (
              classification_alias_paths_transitive.full_path_ids
            )
            JOIN classification_alias_paths cap ON cap.id = c2.id
          WHERE classification_contents.content_data_id = ANY (thing_ids)
          ORDER BY classification_contents.content_data_id,
            classification_contents.relation,
            c2.id,
            "direct" DESC,
            "row_number"
        ),
        new_collected_classification_contents AS (
          SELECT full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            CASE
              WHEN full_classification_content_relations.direct THEN 'direct'
              WHEN full_classification_content_relations.row_number > 1 THEN 'broader'
              ELSE 'related'
            END AS "link_type",
            full_classification_content_relations.relation
          FROM full_classification_content_relations
        ),
        deleted_collected_classification_contents AS (
          DELETE FROM collected_classification_contents
          WHERE collected_classification_contents.thing_id = ANY(thing_ids)
            AND NOT EXISTS (
              SELECT 1
              FROM new_collected_classification_contents
              WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id
                AND new_collected_classification_contents.relation = collected_classification_contents.relation
                AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id
            )
        )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          link_type,
          relation
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.link_type,
        new_collected_classification_contents.relation
      FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type;

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_from_ca_ids_transitive(ca_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(ca_ids, 1) > 0 THEN WITH full_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_contents.relation,
              c2.id
            ) classification_contents.content_data_id "thing_id",
            c2.id "classification_alias_id",
            c2.concept_scheme_id "classification_tree_label_id",
            concepts.id = c2.id "direct",
            classification_contents.relation,
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              classification_alias_paths_transitive.id,
              c2.concept_scheme_id
              ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
            ) AS "row_number"
          FROM classification_contents
            JOIN concepts ON concepts.classification_id = classification_contents.classification_id
            JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id
            JOIN concepts c2 ON c2.id = ANY (
              classification_alias_paths_transitive.full_path_ids
            )
            JOIN classification_alias_paths cap ON cap.id = c2.id
          WHERE cap.full_path_ids && ca_ids
          ORDER BY classification_contents.content_data_id,
            classification_contents.relation,
            c2.id,
            "direct" DESC,
            "row_number"
        ),
        new_collected_classification_contents AS (
          SELECT full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            CASE
              WHEN full_classification_content_relations.direct THEN 'direct'
              WHEN full_classification_content_relations.row_number > 1 THEN 'broader'
              ELSE 'related'
            END AS "link_type",
            full_classification_content_relations.relation
          FROM full_classification_content_relations
          WHERE full_classification_content_relations.classification_alias_id = ANY(ca_ids)
        ),
        deleted_collected_classification_contents AS (
          DELETE FROM collected_classification_contents
          WHERE collected_classification_contents.classification_alias_id = ANY(ca_ids)
            AND NOT EXISTS (
              SELECT 1
              FROM new_collected_classification_contents
              WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id
                AND new_collected_classification_contents.relation = collected_classification_contents.relation
                AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id
            )
        )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          link_type,
          relation
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.link_type,
        new_collected_classification_contents.relation
      FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type;

      END IF;

      END;

      $$;
    SQL
  end
end

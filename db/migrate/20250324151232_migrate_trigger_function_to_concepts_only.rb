# frozen_string_literal: true

class MigrateTriggerFunctionToConceptsOnly < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_collected_classification_content_relations(
          content_ids uuid [],
          excluded_classification_ids uuid []
        ) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(content_ids, 1) > 0 THEN WITH direct_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_contents.relation,
              c2.id
            ) classification_contents.content_data_id "thing_id",
            c2.id "classification_alias_id",
            c2.concept_scheme_id "classification_tree_label_id",
            classification_contents.relation,
            CASE
              WHEN concepts.id = c2.id THEN 'direct'
              ELSE 'broader'
            END "link_type"
          FROM classification_contents
            JOIN concepts ON concepts.classification_id = classification_contents.classification_id
            JOIN classification_alias_paths ON concepts.id = classification_alias_paths.id
            JOIN concepts c2 ON c2.id = ANY (classification_alias_paths.full_path_ids)
            JOIN classification_alias_paths cap ON cap.id = c2.id
          WHERE classification_contents.content_data_id = ANY (content_ids)
            AND classification_contents.classification_id <> ALL (excluded_classification_ids)
        ),
        related_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_contents.relation,
              c2.id
            ) classification_contents.content_data_id "thing_id",
            c2.id "classification_alias_id",
            c2.concept_scheme_id "classification_tree_label_id",
            classification_contents.relation,
            'related' AS "link_type"
          FROM classification_contents
            JOIN concepts ON concepts.classification_id = classification_contents.classification_id
            JOIN concept_links ON concepts.id = concept_links.child_id
            AND concept_links.link_type = 'related'
            JOIN classification_alias_paths ON concept_links.parent_id = classification_alias_paths.id
            JOIN concepts c2 ON c2.id = ANY (classification_alias_paths.full_path_ids)
            JOIN classification_alias_paths cap ON cap.id = c2.id
          WHERE classification_contents.content_data_id = ANY (content_ids)
            AND classification_contents.classification_id <> ALL (excluded_classification_ids)
        ),
        full_classification_content_relations AS (
          SELECT *
          FROM direct_classification_content_relations
          UNION
          SELECT *
          FROM related_classification_content_relations
        ),
        new_collected_classification_contents AS (
          SELECT DISTINCT ON (
              full_classification_content_relations.thing_id,
              full_classification_content_relations.relation,
              full_classification_content_relations.classification_alias_id
            ) full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            full_classification_content_relations.relation,
            full_classification_content_relations.link_type
          FROM full_classification_content_relations
        ),
        deleted_collected_classification_contents AS (
          DELETE FROM collected_classification_contents
          WHERE collected_classification_contents.id IN (
              SELECT ccc.id
              FROM collected_classification_contents ccc
              WHERE ccc.thing_id = ANY(content_ids)
                AND NOT EXISTS (
                  SELECT 1
                  FROM new_collected_classification_contents
                  WHERE new_collected_classification_contents.thing_id = ccc.thing_id
                    AND new_collected_classification_contents.relation = ccc.relation
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

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_concept_links_ccc_relations_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_collected_classification_content_relations (
          ARRAY_AGG(to_update.content_data_id),
          ARRAY []::uuid []
        )
      FROM (
          SELECT DISTINCT cc.content_data_id
          FROM changed_concept_links
            JOIN concepts c1 ON c1.id = changed_concept_links.parent_id
            JOIN classification_contents cc ON cc.classification_id = c1.classification_id
          WHERE c1.id IS NOT NULL
            AND changed_concept_links.link_type = 'related'
          UNION
          SELECT DISTINCT cc.content_data_id
          FROM changed_concept_links
            JOIN concepts c1 ON c1.id = changed_concept_links.child_id
            JOIN classification_contents cc ON cc.classification_id = c1.classification_id
          WHERE c1.id IS NOT NULL
            AND changed_concept_links.link_type = 'related'
        ) AS to_update;

      RETURN NEW;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.update_concept_links_ccc_relations_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_collected_classification_content_relations (
          ARRAY_AGG(to_update.content_data_id),
          ARRAY []::uuid []
        )
      FROM (
          SELECT DISTINCT cc.content_data_id
          FROM old_concept_links
            JOIN concepts c1 ON c1.id = old_concept_links.parent_id
            JOIN classification_contents cc ON cc.classification_id = c1.classification_id
          WHERE c1.id IS NOT NULL
            AND old_concept_links.link_type = 'related'
          UNION
          SELECT DISTINCT cc.content_data_id
          FROM old_concept_links
            JOIN concepts c1 ON c1.id = old_concept_links.child_id
            JOIN classification_contents cc ON cc.classification_id = c1.classification_id
          WHERE c1.id IS NOT NULL
            AND old_concept_links.link_type = 'related'
          UNION
          SELECT DISTINCT cc.content_data_id
          FROM new_concept_links
            JOIN concepts c1 ON c1.id = new_concept_links.parent_id
            JOIN classification_contents cc ON cc.classification_id = c1.classification_id
          WHERE c1.id IS NOT NULL
            AND new_concept_links.link_type = 'related'
          UNION
          SELECT DISTINCT cc.content_data_id
          FROM new_concept_links
            JOIN concepts c1 ON c1.id = new_concept_links.child_id
            JOIN classification_contents cc ON cc.classification_id = c1.classification_id
          WHERE c1.id IS NOT NULL
            AND new_concept_links.link_type = 'related'
        ) AS to_update;

      RETURN NEW;

      END;

      $$;

      DROP TRIGGER IF EXISTS delete_collected_classification_content_relations_trigger_1 ON public.classification_groups;

      DROP TRIGGER IF EXISTS update_deleted_at_ccc_relations_trigger_4 ON public.classification_groups;

      DROP TRIGGER IF EXISTS generate_collected_classification_content_relations_trigger_4 ON public.classification_groups;

      DROP TRIGGER IF EXISTS update_ccc_relations_trigger_4 ON public.classification_groups;

      DROP FUNCTION IF EXISTS public.delete_collected_classification_content_relations_trigger_1();

      DROP FUNCTION IF EXISTS public.generate_collected_classification_content_relations_trigger_4();
      DROP FUNCTION IF EXISTS public.update_collected_classification_content_relations_trigger_4();

      CREATE OR REPLACE TRIGGER delete_concept_links_ccc_relations_trigger_1
      AFTER DELETE ON public.concept_links REFERENCING OLD TABLE AS changed_concept_links FOR EACH STATEMENT EXECUTE FUNCTION public.generate_concept_links_ccc_relations_trigger_1();

      CREATE OR REPLACE TRIGGER generate_concept_links_ccc_relations_trigger_4
      AFTER
      INSERT ON public.concept_links REFERENCING NEW TABLE AS changed_concept_links FOR EACH STATEMENT EXECUTE FUNCTION public.generate_concept_links_ccc_relations_trigger_1();

      CREATE OR REPLACE TRIGGER update_concept_links_ccc_relations_trigger_4
      AFTER
      UPDATE ON public.concept_links REFERENCING OLD TABLE AS old_concept_links NEW TABLE AS new_concept_links FOR EACH STATEMENT EXECUTE FUNCTION public.update_concept_links_ccc_relations_trigger_1();
    SQL
  end

  def down
  end
end

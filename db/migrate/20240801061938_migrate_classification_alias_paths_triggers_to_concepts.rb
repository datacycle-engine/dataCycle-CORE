# frozen_string_literal: true

class MigrateClassificationAliasPathsTriggersToConcepts < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS update_classification_alias_paths_trigger ON public.classification_aliases;

      DROP FUNCTION IF EXISTS public.generate_classification_alias_paths_trigger_1();

      DROP TRIGGER IF EXISTS update_classification_alias_paths_trigger ON public.classification_tree_labels;

      DROP FUNCTION IF EXISTS public.generate_classification_alias_paths_trigger_3();

      DROP TRIGGER IF EXISTS generate_classification_alias_paths_trigger ON public.classification_trees;

      DROP TRIGGER IF EXISTS update_classification_alias_paths_trigger ON public.classification_trees;

      DROP FUNCTION IF EXISTS public.generate_classification_alias_paths_trigger_2();

      DROP FUNCTION IF EXISTS public.generate_classification_alias_paths();

      CREATE OR REPLACE FUNCTION public.upsert_ca_paths(concept_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(concept_ids, 1) > 0 THEN WITH RECURSIVE paths(
        id,
        parent_id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        tree_label_id
      ) AS (
        SELECT c.id,
          cl.parent_id,
          ARRAY []::uuid [],
          ARRAY [c.id],
          ARRAY [c.internal_name],
          c.concept_scheme_id
        FROM concepts c
          JOIN concept_links cl ON cl.child_id = c.id
          AND cl.link_type = 'broader'
        WHERE c.id = ANY(concept_ids)
        UNION ALL
        SELECT paths.id,
          cl.parent_id,
          ancestor_ids || c.id,
          full_path_ids || c.id,
          full_path_names || c.internal_name,
          c.concept_scheme_id
        FROM concepts c
          JOIN paths ON paths.parent_id = c.id
          JOIN concept_links cl ON cl.child_id = c.id
          AND cl.link_type = 'broader'
        WHERE c.id <> ALL (paths.full_path_ids)
      ),
      child_paths(
        id,
        ancestor_ids,
        full_path_ids,
        full_path_names
      ) AS (
        SELECT paths.id AS id,
          paths.ancestor_ids AS ancestor_ids,
          paths.full_path_ids AS full_path_ids,
          paths.full_path_names || cs.name AS full_path_names
        FROM paths
          JOIN concept_schemes cs ON cs.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL
        UNION ALL
        SELECT c.id AS id,
          (cl.parent_id || p1.ancestor_ids) AS ancestors_ids,
          (c.id || p1.full_path_ids) AS full_path_ids,
          (c.internal_name || p1.full_path_names) AS full_path_names
        FROM concepts c
          JOIN concept_links cl ON cl.child_id = c.id
          AND cl.link_type = 'broader'
          JOIN child_paths p1 ON p1.id = cl.parent_id
        WHERE c.id <> ALL (p1.full_path_ids)
      )
      INSERT INTO classification_alias_paths (
          id,
          ancestor_ids,
          full_path_ids,
          full_path_names
        )
      SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_pkey DO
      UPDATE
      SET ancestor_ids = EXCLUDED.ancestor_ids,
        full_path_ids = EXCLUDED.full_path_ids,
        full_path_names = EXCLUDED.full_path_names;

      END IF;

      END;

      $$;

      DELETE FROM classification_alias_paths
      WHERE NOT EXISTS (
          SELECT 1
          FROM concepts
          WHERE concepts.id = classification_alias_paths.id
        );

      ALTER TABLE IF EXISTS public.classification_alias_paths
      ADD CONSTRAINT fk_cap_concepts FOREIGN KEY (id) REFERENCES public.concepts (id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE CASCADE;

      CREATE OR REPLACE FUNCTION public.concepts_create_paths_trigger_function() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $$ BEGIN PERFORM upsert_ca_paths (ARRAY_AGG(new_concepts.id))
      FROM new_concepts;

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE TRIGGER concepts_create_paths_trigger
      AFTER
      INSERT ON public.concepts REFERENCING NEW TABLE AS new_concepts FOR EACH STATEMENT EXECUTE FUNCTION public.concepts_create_paths_trigger_function();

      CREATE OR REPLACE FUNCTION public.concepts_update_paths_trigger_function() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $$ BEGIN PERFORM upsert_ca_paths (ARRAY_AGG(updated_concepts.id))
      FROM (
          SELECT DISTINCT new_concepts.id
          FROM old_concepts
            JOIN new_concepts ON old_concepts.id = new_concepts.id
          WHERE old_concepts.internal_name IS DISTINCT
          FROM new_concepts.internal_name
            OR old_concepts.concept_scheme_id IS DISTINCT
          FROM new_concepts.concept_scheme_id
        ) "updated_concepts";

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE TRIGGER concepts_update_paths_trigger
      AFTER
      UPDATE ON public.concepts REFERENCING NEW TABLE AS new_concepts OLD TABLE AS old_concepts FOR EACH STATEMENT EXECUTE FUNCTION public.concepts_update_paths_trigger_function();

      CREATE OR REPLACE FUNCTION public.concept_links_create_paths_trigger_function() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $$ BEGIN PERFORM upsert_ca_paths (ARRAY_AGG(new_concept_links.child_id))
      FROM new_concept_links
      WHERE new_concept_links.link_type = 'broader';

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE TRIGGER concept_links_create_paths_trigger
      AFTER
      INSERT ON public.concept_links REFERENCING NEW TABLE AS new_concept_links FOR EACH STATEMENT EXECUTE FUNCTION public.concept_links_create_paths_trigger_function();

      CREATE OR REPLACE FUNCTION public.concept_links_update_paths_trigger_function() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $$ BEGIN PERFORM upsert_ca_paths (ARRAY_AGG(updated_concept_links.child_id))
      FROM (
          SELECT DISTINCT new_concept_links.child_id
          FROM old_concept_links
            JOIN new_concept_links ON old_concept_links.id = new_concept_links.id
          WHERE new_concept_links.link_type = 'broader'
            AND old_concept_links.parent_id IS DISTINCT
          FROM new_concept_links.parent_id
            OR old_concept_links.child_id IS DISTINCT
          FROM new_concept_links.child_id
        ) "updated_concept_links";

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE TRIGGER concept_links_update_paths_trigger
      AFTER
      UPDATE ON public.concept_links REFERENCING NEW TABLE AS new_concept_links OLD TABLE AS old_concept_links FOR EACH STATEMENT EXECUTE FUNCTION public.concept_links_update_paths_trigger_function();

      CREATE OR REPLACE FUNCTION public.concept_schemes_update_paths_trigger_function() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $$ BEGIN PERFORM upsert_ca_paths (ARRAY_AGG(updated_concepts.id))
      FROM (
          SELECT DISTINCT concepts.id
          FROM old_concept_schemes
            JOIN new_concept_schemes ON old_concept_schemes.id = new_concept_schemes.id
            JOIN concepts ON concepts.concept_scheme_id = new_concept_schemes.id
          WHERE old_concept_schemes.name IS DISTINCT
          FROM new_concept_schemes.name
        ) "updated_concepts";

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE TRIGGER concept_schemes_update_paths_trigger
      AFTER
      UPDATE ON public.concept_schemes REFERENCING NEW TABLE AS new_concept_schemes OLD TABLE AS old_concept_schemes FOR EACH STATEMENT EXECUTE FUNCTION public.concept_schemes_update_paths_trigger_function();

      CREATE OR REPLACE FUNCTION public.update_classification_tree_tree_label_id_concept_trigger() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $BODY$ BEGIN
      UPDATE concepts
      SET concept_scheme_id = uct.classification_tree_label_id
      FROM (
          SELECT nct.*
          FROM old_classification_trees oct
            JOIN new_classification_trees nct ON oct.id = nct.id
          WHERE nct.deleted_at IS NULL
            AND nct.classification_tree_label_id IS DISTINCT
          FROM oct.classification_tree_label_id
        ) "uct"
      WHERE uct.classification_alias_id = concepts.id;

      RETURN NULL;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER update_classification_tree_tree_label_id_concept
      AFTER
      UPDATE ON public.classification_trees REFERENCING NEW TABLE AS new_classification_trees OLD TABLE AS old_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION public.update_classification_tree_tree_label_id_concept_trigger();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS concept_schemes_update_paths_trigger ON public.concept_schemes;

      DROP FUNCTION IF EXISTS public.concept_schemes_update_paths_trigger_function();

      DROP TRIGGER IF EXISTS concept_links_update_paths_trigger ON public.concept_links;

      DROP FUNCTION IF EXISTS public.concept_links_update_paths_trigger_function();

      DROP TRIGGER IF EXISTS concept_links_create_paths_trigger ON public.concept_links;

      DROP FUNCTION IF EXISTS public.concept_links_create_paths_trigger_function();

      DROP TRIGGER IF EXISTS concepts_update_paths_trigger ON public.concepts;

      DROP FUNCTION IF EXISTS public.concepts_update_paths_trigger_function();

      DROP TRIGGER IF EXISTS concepts_create_paths_trigger ON public.concepts;

      DROP FUNCTION IF EXISTS public.concepts_create_paths_trigger_function();

      ALTER TABLE IF EXISTS public.classification_alias_paths DROP CONSTRAINT IF EXISTS fk_cap_concepts;

      DROP FUNCTION IF EXISTS public.upsert_ca_paths();

      CREATE OR REPLACE FUNCTION public.generate_classification_alias_paths(classification_alias_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM classification_alias_paths
      WHERE id = ANY(classification_alias_ids);

      WITH RECURSIVE paths(
        id,
        parent_id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        tree_label_id
      ) AS (
        SELECT classification_aliases.id,
          classification_trees.parent_classification_alias_id,
          ARRAY []::uuid [],
          ARRAY [classification_aliases.id],
          ARRAY [classification_aliases.internal_name],
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
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN paths ON paths.parent_id = classification_trees.classification_alias_id
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
      )
      INSERT INTO classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names)
      SELECT paths.id,
        paths.ancestor_ids,
        paths.full_path_ids,
        paths.full_path_names || classification_tree_labels.name
      FROM paths
        JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
      WHERE paths.parent_id IS NULL;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.generate_classification_alias_paths_trigger_1() RETURNS TRIGGER LANGUAGE 'plpgsql' COST 100 VOLATILE NOT LEAKPROOF AS $BODY$ BEGIN PERFORM generate_classification_alias_paths (array_agg(id) || ARRAY [NEW.id]::UUID [])
      FROM (
          SELECT id
          FROM classification_alias_paths
          WHERE NEW.id = ANY (ancestor_ids)
        ) "new_child_classification_aliases";

      RETURN NEW;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER update_classification_alias_paths_trigger
      AFTER
      UPDATE OF internal_name ON public.classification_aliases FOR EACH ROW
        WHEN (
          old.internal_name::text IS DISTINCT
          FROM new.internal_name::text
        ) EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_1();

      CREATE OR REPLACE FUNCTION public.generate_classification_alias_paths_trigger_3() RETURNS TRIGGER LANGUAGE 'plpgsql' COST 100 VOLATILE NOT LEAKPROOF AS $BODY$ BEGIN PERFORM generate_classification_alias_paths (array_agg(classification_alias_id))
      FROM (
          SELECT classification_alias_id
          FROM classification_trees
          WHERE classification_trees.classification_tree_label_id = NEW.id
        ) "changed_tree_classification_aliases";

      RETURN NEW;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER update_classification_alias_paths_trigger
      AFTER
      UPDATE OF name ON public.classification_tree_labels FOR EACH ROW
        WHEN (
          old.name::text IS DISTINCT
          FROM new.name::text
        ) EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_3();

      CREATE OR REPLACE FUNCTION public.generate_classification_alias_paths_trigger_2() RETURNS TRIGGER LANGUAGE 'plpgsql' COST 100 VOLATILE NOT LEAKPROOF AS $BODY$ BEGIN PERFORM generate_classification_alias_paths (
          array_agg(id) || ARRAY [NEW.classification_alias_id]::UUID []
        )
      FROM (
          SELECT id
          FROM classification_alias_paths
          WHERE NEW.classification_alias_id = ANY (ancestor_ids)
        ) "changed_child_classification_aliases";

      RETURN NEW;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER generate_classification_alias_paths_trigger
      AFTER
      INSERT ON public.classification_trees FOR EACH ROW EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_2();

      CREATE OR REPLACE TRIGGER update_classification_alias_paths_trigger
      AFTER
      UPDATE OF parent_classification_alias_id,
        classification_alias_id,
        classification_tree_label_id ON public.classification_trees FOR EACH ROW
        WHEN (
          old.parent_classification_alias_id IS DISTINCT
          FROM new.parent_classification_alias_id
            OR old.classification_alias_id IS DISTINCT
          FROM new.classification_alias_id
            OR new.classification_tree_label_id IS DISTINCT
          FROM old.classification_tree_label_id
        ) EXECUTE FUNCTION public.generate_classification_alias_paths_trigger_2();
    SQL
  end
end

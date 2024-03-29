# frozen_string_literal: true

class AddTriggersForNewConceptTables < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION insert_concept_schemes_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_schemes(
          id,
          name,
          external_system_id,
          internal,
          visibility,
          change_behaviour,
          created_at,
          updated_at
        )
      SELECT nctl.id,
        nctl.name,
        nctl.external_source_id,
        nctl.internal,
        nctl.visibility,
        nctl.change_behaviour,
        nctl.created_at,
        nctl.updated_at
      FROM new_classification_tree_labels nctl ON CONFLICT DO NOTHING;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER insert_concept_schemes_trigger
      AFTER
      INSERT ON classification_tree_labels REFERENCING NEW TABLE AS new_classification_tree_labels FOR EACH STATEMENT EXECUTE FUNCTION insert_concept_schemes_trigger_function();

      CREATE OR REPLACE FUNCTION update_concept_schemes_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      UPDATE concept_schemes
      SET name = uctl.name,
        external_system_id = uctl.external_source_id,
        internal = uctl.internal,
        visibility = uctl.visibility,
        change_behaviour = uctl.change_behaviour,
        updated_at = uctl.updated_at
      FROM (
          SELECT nctl.*
          FROM old_classification_tree_labels octl
            INNER JOIN new_classification_tree_labels nctl ON octl.id = nctl.id
          WHERE octl.name IS DISTINCT
          FROM nctl.name
            OR octl.external_source_id IS DISTINCT
          FROM nctl.external_source_id
            OR octl.internal IS DISTINCT
          FROM nctl.internal
            OR octl.visibility IS DISTINCT
          FROM nctl.visibility
            OR octl.change_behaviour IS DISTINCT
          FROM nctl.change_behaviour
            OR octl.updated_at IS DISTINCT
          FROM nctl.updated_at
        ) "uctl"
      WHERE uctl.id = concept_schemes.id;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER update_concept_schemes_trigger
      AFTER
      UPDATE ON classification_tree_labels REFERENCING NEW TABLE AS new_classification_tree_labels OLD TABLE AS old_classification_tree_labels FOR EACH STATEMENT EXECUTE FUNCTION update_concept_schemes_trigger_function();

      CREATE OR REPLACE FUNCTION delete_concept_schemes_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM concept_schemes
      WHERE concept_schemes.id IN (
          SELECT nctl.id
          FROM old_classification_tree_labels octl
            INNER JOIN new_classification_tree_labels nctl ON octl.id = nctl.id
          WHERE octl.deleted_at IS NULL
            AND nctl.deleted_at IS NOT NULL
        );

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_concept_schemes_trigger
      AFTER
      UPDATE ON classification_tree_labels REFERENCING NEW TABLE AS new_classification_tree_labels OLD TABLE AS old_classification_tree_labels FOR EACH STATEMENT EXECUTE FUNCTION delete_concept_schemes_trigger_function();

      CREATE OR REPLACE FUNCTION insert_concepts_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concepts(
          id,
          internal_name,
          name_i18n,
          description_i18n,
          external_system_id,
          external_key,
          order_a,
          assignable,
          internal,
          uri,
          ui_configs,
          created_at,
          updated_at
        )
      SELECT ca.id,
        ca.internal_name,
        coalesce(ca.name_i18n, '{}'),
        coalesce(ca.description_i18n, '{}'),
        ca.external_source_id,
        ca.external_key,
        ca.order_a,
        ca.assignable,
        ca.internal,
        ca.uri,
        coalesce(ca.ui_configs, '{}'),
        NOW(),
        NOW()
      FROM new_classification_aliases ca ON CONFLICT DO NOTHING;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER insert_concepts_trigger
      AFTER
      INSERT ON classification_aliases REFERENCING NEW TABLE AS new_classification_aliases FOR EACH STATEMENT EXECUTE FUNCTION insert_concepts_trigger_function();

      CREATE OR REPLACE FUNCTION update_concepts_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      UPDATE concepts
      SET internal_name = uca.internal_name,
        name_i18n = coalesce(uca.name_i18n, '{}'),
        description_i18n = coalesce(uca.description_i18n, '{}'),
        external_system_id = uca.external_source_id,
        external_key = coalesce(uca.external_key, concepts.external_key),
        order_a = uca.order_a,
        assignable = uca.assignable,
        internal = uca.internal,
        uri = uca.uri,
        ui_configs = coalesce(uca.ui_configs, '{}'),
        updated_at = uca.updated_at
      FROM (
          SELECT nca.*
          FROM old_classification_aliases oca
            INNER JOIN new_classification_aliases nca ON oca.id = nca.id
          WHERE oca.internal_name IS DISTINCT
          FROM nca.internal_name
            OR oca.name_i18n IS DISTINCT
          FROM nca.name_i18n
            OR oca.description_i18n IS DISTINCT
          FROM nca.description_i18n
            OR oca.external_source_id IS DISTINCT
          FROM nca.external_source_id
            OR oca.external_key IS DISTINCT
          FROM nca.external_key
            OR oca.order_a IS DISTINCT
          FROM nca.order_a
            OR oca.assignable IS DISTINCT
          FROM nca.assignable
            OR oca.internal IS DISTINCT
          FROM nca.internal
            OR oca.uri IS DISTINCT
          FROM nca.uri
            OR oca.ui_configs IS DISTINCT
          FROM nca.ui_configs
            OR oca.updated_at IS DISTINCT
          FROM nca.updated_at
        ) "uca"
      WHERE uca.id = concepts.id;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER update_concepts_trigger
      AFTER
      UPDATE ON classification_aliases REFERENCING NEW TABLE AS new_classification_aliases OLD TABLE AS old_classification_aliases FOR EACH STATEMENT EXECUTE FUNCTION update_concepts_trigger_function();

      CREATE OR REPLACE FUNCTION delete_concepts_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM concepts
      WHERE concepts.id IN (
          SELECT nca.id
          FROM old_classification_aliases oca
            INNER JOIN new_classification_aliases nca ON oca.id = nca.id
          WHERE oca.deleted_at IS NULL
            AND nca.deleted_at IS NOT NULL
        );

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_concepts_trigger
      AFTER
      UPDATE ON classification_aliases REFERENCING NEW TABLE AS new_classification_aliases OLD TABLE AS old_classification_aliases FOR EACH STATEMENT EXECUTE FUNCTION delete_concepts_trigger_function();

      CREATE OR REPLACE FUNCTION upsert_concept_tables_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN WITH groups AS (
          SELECT cg.*,
            (
              (
                SELECT COUNT(cg1.id) <= 1
                FROM classification_groups cg1
                WHERE cg1.classification_alias_id = cg.classification_alias_id
                  AND cg1.deleted_at IS NULL
              )
            ) AS PRIMARY
          FROM new_classification_groups cg
        ),
        updated_concepts AS (
          UPDATE concepts
          SET classification_id = groups.classification_id,
            external_system_id = coalesce(
              ca.external_source_id,
              c.external_source_id,
              concepts.external_system_id
            ),
            external_key = coalesce(
              ca.external_key,
              c.external_key,
              concepts.external_key
            ),
            uri = coalesce(ca.uri, c.uri, concepts.uri)
          FROM groups
            LEFT OUTER JOIN classifications c ON c.id = groups.classification_id
            AND c.deleted_at IS NULL
            LEFT OUTER JOIN classification_aliases ca ON ca.id = groups.classification_alias_id
            AND ca.deleted_at IS NULL
          WHERE concepts.id = groups.classification_alias_id
            AND groups.primary = TRUE
        )
      INSERT INTO concept_links(id, parent_id, child_id, link_type)
      SELECT groups.id,
        groups.classification_alias_id,
        pcg.classification_alias_id,
        'related'
      FROM groups
        JOIN primary_classification_groups pcg ON pcg.classification_id = groups.classification_id
        AND pcg.deleted_at IS NULL
      WHERE groups.primary = false ON CONFLICT DO NOTHING;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER upsert_concept_tables_trigger
      AFTER
      INSERT ON classification_groups REFERENCING NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION upsert_concept_tables_trigger_function();

      CREATE OR REPLACE FUNCTION update_concept_links_groups_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      UPDATE concept_links
      SET parent_id = ucg.classification_alias_id,
        child_id = ucg.mapped_ca_id
      FROM (
          SELECT ncg.*,
            pcg.classification_alias_id AS mapped_ca_id
          FROM old_classification_groups ocg
            JOIN new_classification_groups ncg ON ocg.id = ncg.id
            JOIN primary_classification_groups pcg ON pcg.classification_id = ncg.classification_id
            AND pcg.deleted_at IS NULL
          WHERE ocg.classification_id IS DISTINCT
          FROM ncg.classification_id
            OR ocg.classification_alias_id IS DISTINCT
          FROM ncg.classification_alias_id
        ) "ucg"
      WHERE ucg.id = concept_links.id;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER update_concept_links_groups_trigger
      AFTER
      UPDATE ON classification_groups REFERENCING NEW TABLE AS new_classification_groups OLD TABLE AS old_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION update_concept_links_groups_trigger_function();

      CREATE OR REPLACE FUNCTION delete_concept_links_groups_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM concept_links
      WHERE concept_links.id IN (
          SELECT ncg.id
          FROM old_classification_groups ocg
            INNER JOIN new_classification_groups ncg ON ocg.id = ncg.id
          WHERE ocg.deleted_at IS NULL
            AND ncg.deleted_at IS NOT NULL
        );

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_concept_links_groups_trigger
      AFTER
      UPDATE ON classification_groups REFERENCING NEW TABLE AS new_classification_groups OLD TABLE AS old_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION delete_concept_links_groups_trigger_function();

      CREATE OR REPLACE FUNCTION delete_concept_links_groups_trigger_function2() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM concept_links
      WHERE concept_links.id IN (
          SELECT ocg.id
          FROM old_classification_groups ocg
        );

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_concept_links_groups_trigger2
      AFTER DELETE ON classification_groups REFERENCING OLD TABLE AS old_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION delete_concept_links_groups_trigger_function2();

      CREATE OR REPLACE FUNCTION insert_concept_links_trees_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      WITH updated_concepts AS (
        UPDATE concepts
        SET concept_scheme_id = new_classification_trees.classification_tree_label_id
        FROM new_classification_trees
        WHERE new_classification_trees.classification_alias_id = concepts.id
      )
      INSERT INTO concept_links(id, parent_id, child_id, link_type)
      SELECT new_classification_trees.id,
        new_classification_trees.parent_classification_alias_id,
        new_classification_trees.classification_alias_id,
        'broader'
      FROM new_classification_trees ON CONFLICT DO NOTHING;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER insert_concept_links_trees_trigger
      AFTER
      INSERT ON classification_trees REFERENCING NEW TABLE AS new_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION insert_concept_links_trees_trigger_function();

      CREATE OR REPLACE FUNCTION update_concept_links_trees_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      UPDATE concept_links
      SET parent_id = uct.parent_classification_alias_id,
        child_id = uct.classification_alias_id
      FROM (
          SELECT nct.*
          FROM old_classification_trees oct
            JOIN new_classification_trees nct ON oct.id = nct.id
          WHERE oct.classification_alias_id IS DISTINCT
          FROM nct.classification_alias_id
            OR oct.parent_classification_alias_id IS DISTINCT
          FROM nct.parent_classification_alias_id
        ) "uct"
      WHERE uct.id = concept_links.id;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER update_concept_links_trees_trigger
      AFTER
      UPDATE ON classification_trees REFERENCING NEW TABLE AS new_classification_trees OLD TABLE AS old_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION update_concept_links_trees_trigger_function();

      CREATE OR REPLACE FUNCTION delete_concept_links_trees_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM concept_links
      WHERE concept_links.id IN (
          SELECT nct.id
          FROM old_classification_trees oct
            INNER JOIN new_classification_trees nct ON oct.id = nct.id
          WHERE oct.deleted_at IS NULL
            AND nct.deleted_at IS NOT NULL
        );

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_concept_links_trees_trigger
      AFTER
      UPDATE ON classification_trees REFERENCING NEW TABLE AS new_classification_trees OLD TABLE AS old_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION delete_concept_links_trees_trigger_function();

      CREATE OR REPLACE FUNCTION delete_concept_links_trees_trigger_function2() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM concept_links
      WHERE concept_links.id IN (
          SELECT oct.id
          FROM old_classification_trees oct
        );

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_concept_links_trees_trigger2
      AFTER DELETE ON classification_trees REFERENCING OLD TABLE AS old_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION delete_concept_links_trees_trigger_function2();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS insert_concept_schemes_trigger ON classification_tree_labels;
      DROP TRIGGER IF EXISTS update_concept_schemes_trigger ON classification_tree_labels;
      DROP TRIGGER IF EXISTS delete_concept_schemes_trigger ON classification_tree_labels;
      DROP TRIGGER IF EXISTS insert_concepts_trigger ON classification_aliases;
      DROP TRIGGER IF EXISTS update_concepts_trigger ON classification_aliases;
      DROP TRIGGER IF EXISTS delete_concepts_trigger ON classification_aliases;
      DROP TRIGGER IF EXISTS upsert_concept_tables_trigger ON classification_groups;
      DROP TRIGGER IF EXISTS update_concept_links_groups_trigger ON classification_groups;
      DROP TRIGGER IF EXISTS delete_concept_links_groups_trigger ON classification_groups;
      DROP TRIGGER IF EXISTS delete_concept_links_groups_trigger2 ON classification_groups;
      DROP TRIGGER IF EXISTS insert_concept_links_trees_trigger ON classification_trees;
      DROP TRIGGER IF EXISTS update_concept_links_trees_trigger ON classification_trees;
      DROP TRIGGER IF EXISTS delete_concept_links_trees_trigger ON classification_trees;
      DROP TRIGGER IF EXISTS delete_concept_links_trees_trigger2 ON classification_trees;

      DROP FUNCTION IF EXISTS insert_concept_schemes_trigger_function;
      DROP FUNCTION IF EXISTS update_concept_schemes_trigger_function;
      DROP FUNCTION IF EXISTS delete_concept_schemes_trigger_function;
      DROP FUNCTION IF EXISTS insert_concepts_trigger_function;
      DROP FUNCTION IF EXISTS update_concepts_trigger_function;
      DROP FUNCTION IF EXISTS delete_concepts_trigger_function;
      DROP FUNCTION IF EXISTS upsert_concept_tables_trigger_function;
      DROP FUNCTION IF EXISTS update_concept_links_groups_trigger_function;
      DROP FUNCTION IF EXISTS delete_concept_links_groups_trigger_function;
      DROP FUNCTION IF EXISTS delete_concept_links_groups_trigger_function2;
      DROP FUNCTION IF EXISTS insert_concept_links_trees_trigger_function;
      DROP FUNCTION IF EXISTS update_concept_links_trees_trigger_function;
      DROP FUNCTION IF EXISTS delete_concept_links_trees_trigger_function;
      DROP FUNCTION IF EXISTS delete_concept_links_trees_trigger_function2;
      DROP FUNCTION IF EXISTS upsert_concept_tables_function;
    SQL
  end
end

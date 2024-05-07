# frozen_string_literal: true

class PrefillNewConceptTables < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE classification_aliases
      SET deleted_at = NOW()
      WHERE classification_aliases.id IN (
          SELECT ca.id
          FROM classification_aliases ca
            LEFT OUTER JOIN primary_classification_groups pcg ON pcg.classification_alias_id = ca.id
            LEFT OUTER JOIN classifications c ON c.id = pcg.classification_id
          WHERE ca.deleted_at IS NULL
            AND (
              c.deleted_at IS NOT NULL
              OR pcg.deleted_at IS NOT NULL
            )
        );

      UPDATE classifications
      SET deleted_at = NOW()
      WHERE classifications.id IN (
          SELECT c.id
          FROM classification_aliases ca
            LEFT OUTER JOIN primary_classification_groups pcg ON pcg.classification_alias_id = ca.id
            LEFT OUTER JOIN classifications c ON c.id = pcg.classification_id
          WHERE c.deleted_at IS NULL
            AND (
              ca.deleted_at IS NOT NULL
              OR pcg.deleted_at IS NOT NULL
            )
        );

      UPDATE classification_groups
      SET deleted_at = NOW()
      WHERE classification_groups.id IN (
          SELECT pcg.id
          FROM classification_aliases ca
            LEFT OUTER JOIN primary_classification_groups pcg ON pcg.classification_alias_id = ca.id
            LEFT OUTER JOIN classifications c ON c.id = pcg.classification_id
          WHERE pcg.deleted_at IS NULL
            AND (
              ca.deleted_at IS NOT NULL
              OR c.deleted_at IS NOT NULL
            )
        );

      WITH new_classification_tree_labels AS (
        SELECT *
        FROM classification_tree_labels ctl
        WHERE ctl.deleted_at IS NULL
      )
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
    SQL

    execute <<-SQL.squish
      WITH new_classification_groups AS (
        SELECT *
        FROM classification_groups cg
        WHERE cg.deleted_at IS NULL
      ),
      groups AS (
        SELECT cg.*,
          pcg1.id IS NOT NULL AS PRIMARY
        FROM new_classification_groups cg
          LEFT OUTER JOIN primary_classification_groups pcg1 ON pcg1.id = cg.id
          AND pcg1.deleted_at IS NULL
          JOIN primary_classification_groups pcg2 ON pcg2.classification_alias_id = cg.classification_alias_id
          AND pcg2.deleted_at IS NULL
      ),
      inserted_concepts AS (
        INSERT INTO concepts(
            id,
            internal_name,
            name_i18n,
            description_i18n,
            external_system_id,
            external_key,
            concept_scheme_id,
            order_a,
            assignable,
            internal,
            uri,
            ui_configs,
            classification_id,
            created_at,
            updated_at
          )
        SELECT ca.id,
          ca.internal_name,
          coalesce(ca.name_i18n, '{}'),
          coalesce(ca.description_i18n, '{}'),
          coalesce(ca.external_source_id, c.external_source_id),
          coalesce(ca.external_key, c.external_key),
          ct.classification_tree_label_id,
          ca.order_a,
          ca.assignable,
          ca.internal,
          coalesce(ca.uri, c.uri),
          coalesce(ca.ui_configs, '{}'),
          c.id,
          NOW(),
          NOW()
        FROM groups
          JOIN classification_aliases ca ON ca.id = groups.classification_alias_id
          JOIN classifications c ON c.id = groups.classification_id
          JOIN classification_trees ct ON ct.classification_alias_id = groups.classification_alias_id
        WHERE groups.primary = TRUE ON CONFLICT DO NOTHING
      )
      INSERT INTO concept_links(parent_id, child_id, link_type)
      SELECT groups.classification_alias_id,
        pcg.classification_alias_id,
        'related'
      FROM groups
        JOIN primary_classification_groups pcg ON pcg.classification_id = groups.classification_id
        AND pcg.deleted_at IS NULL
      WHERE groups.primary = false ON CONFLICT DO NOTHING;
    SQL

    execute <<-SQL.squish
      WITH new_classification_trees AS (
        SELECT *
        FROM classification_trees ct
        WHERE ct.deleted_at IS NULL
        AND EXISTS (
          SELECT 1 FROM concepts
          WHERE concepts.id = ct.parent_classification_alias_id
          OR ct.parent_classification_alias_id IS NULL
        )
        AND EXISTS (
          SELECT 1 FROM concepts
          WHERE concepts.id = ct.classification_alias_id
        )
      )
      INSERT INTO concept_links(parent_id, child_id, link_type)
      SELECT new_classification_trees.parent_classification_alias_id,
        new_classification_trees.classification_alias_id,
        'broader'
      FROM new_classification_trees ON CONFLICT DO NOTHING;
    SQL
  end

  def down
    execute <<-SQL.squish
      TRUNCATE TABLE concepts
      CASCADE;
    SQL
  end
end

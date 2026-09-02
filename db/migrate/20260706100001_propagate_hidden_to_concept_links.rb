# frozen_string_literal: true

# Redmine #47172 (M2): keep concept_links.hidden in sync with classification_groups.hidden.
#
# * upsert_concept_tables_trigger_function       -> carries `hidden` when a mapping is inserted
# * update_concept_links_groups_trigger_function -> carries `hidden` on update AND now reacts to
#                                                   a hidden-only change (so a toggle propagates)
class PropagateHiddenToConceptLinks < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.upsert_concept_tables_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN WITH groups AS (
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
      INSERT INTO concept_links(id, parent_id, child_id, link_type, hidden)
      SELECT groups.id,
        groups.classification_alias_id,
        pcg.classification_alias_id,
        'related',
        groups.hidden
      FROM groups
        JOIN primary_classification_groups pcg ON pcg.classification_id = groups.classification_id
        AND pcg.deleted_at IS NULL
      WHERE groups.primary = false ON CONFLICT DO NOTHING;
      RETURN NULL;
      END; $$;

      CREATE OR REPLACE FUNCTION public.update_concept_links_groups_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      UPDATE concept_links
      SET parent_id = ucg.classification_alias_id,
        child_id = ucg.mapped_ca_id,
        hidden = ucg.hidden
      FROM (
          SELECT ncg.*,
            pcg.classification_alias_id AS mapped_ca_id
          FROM old_classification_groups ocg
            JOIN new_classification_groups ncg ON ocg.id = ncg.id
            JOIN primary_classification_groups pcg ON pcg.classification_id = ncg.classification_id
            AND pcg.deleted_at IS NULL
          WHERE ocg.classification_id IS DISTINCT FROM ncg.classification_id
            OR ocg.classification_alias_id IS DISTINCT FROM ncg.classification_alias_id
            OR ocg.hidden IS DISTINCT FROM ncg.hidden
        ) "ucg"
      WHERE ucg.id = concept_links.id;
      RETURN NULL;
      END; $$;
    SQL
  end

  def down
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.upsert_concept_tables_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN WITH groups AS (
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
      END; $$;

      CREATE OR REPLACE FUNCTION public.update_concept_links_groups_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
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
          WHERE ocg.classification_id IS DISTINCT FROM ncg.classification_id
            OR ocg.classification_alias_id IS DISTINCT FROM ncg.classification_alias_id
        ) "ucg"
      WHERE ucg.id = concept_links.id;
      RETURN NULL;
      END; $$;
    SQL
  end
end

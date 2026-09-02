# frozen_string_literal: true

# Redmine #50677: with the flag living on the classification tree (20260728100000) and CCC deriving
# `hidden` from it (20260728100001), the per-mapping columns of #47172 have no reader left. The two
# concept-table trigger functions go back to their pre-#47172 form.
class DropHiddenFromClassificationMappings < ActiveRecord::Migration[8.0]
  def up
    execute concept_table_trigger_functions(hidden: false)

    remove_column :concept_link_histories, :hidden, if_exists: true
    remove_column :concept_links, :hidden, if_exists: true
    remove_column :classification_groups, :hidden, if_exists: true
  end

  def down
    add_column :classification_groups, :hidden, :boolean, default: false, null: false, if_not_exists: true
    add_column :concept_links, :hidden, :boolean, default: false, null: false, if_not_exists: true
    add_column :concept_link_histories, :hidden, :boolean, default: false, null: false, if_not_exists: true

    execute concept_table_trigger_functions(hidden: true)

    # re-derive the per-mapping flag from the tree it now lives on
    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;
      UPDATE classification_groups cg
      SET hidden = TRUE
      FROM concepts c
        JOIN concept_schemes cs ON cs.id = c.concept_scheme_id
        AND cs.hidden_mappings
      WHERE c.id = cg.classification_alias_id
        AND c.classification_id IS DISTINCT
      FROM cg.classification_id
        AND cg.deleted_at IS NULL;

      UPDATE concept_links cl
      SET hidden = cg.hidden
      FROM classification_groups cg
      WHERE cg.id = cl.id
        AND cl.hidden IS DISTINCT
      FROM cg.hidden;
    SQL
  end

  private

  def concept_table_trigger_functions(hidden:)
    insert_column = hidden ? ', hidden' : ''
    insert_value = hidden ? ', groups.hidden' : ''
    update_set = hidden ? ', hidden = ucg.hidden' : ''
    change_condition = hidden ? 'OR ocg.hidden IS DISTINCT FROM ncg.hidden' : ''

    <<~SQL.squish
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
      INSERT INTO concept_links(id, parent_id, child_id, link_type#{insert_column})
      SELECT groups.id,
        groups.classification_alias_id,
        pcg.classification_alias_id,
        'related'#{insert_value}
      FROM groups
        JOIN primary_classification_groups pcg ON pcg.classification_id = groups.classification_id
        AND pcg.deleted_at IS NULL
      WHERE groups.primary = false ON CONFLICT DO NOTHING;
      RETURN NULL;
      END; $$;

      CREATE OR REPLACE FUNCTION public.update_concept_links_groups_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      UPDATE concept_links
      SET parent_id = ucg.classification_alias_id,
        child_id = ucg.mapped_ca_id#{update_set}
      FROM (
          SELECT ncg.*,
            pcg.classification_alias_id AS mapped_ca_id
          FROM old_classification_groups ocg
            JOIN new_classification_groups ncg ON ocg.id = ncg.id
            JOIN primary_classification_groups pcg ON pcg.classification_id = ncg.classification_id
            AND pcg.deleted_at IS NULL
          WHERE ocg.classification_id IS DISTINCT FROM ncg.classification_id
            OR ocg.classification_alias_id IS DISTINCT FROM ncg.classification_alias_id
            #{change_condition}
        ) "ucg"
      WHERE ucg.id = concept_links.id;
      RETURN NULL;
      END; $$;
    SQL
  end
end

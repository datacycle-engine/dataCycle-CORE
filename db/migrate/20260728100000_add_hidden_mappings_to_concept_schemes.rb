# frozen_string_literal: true

# Redmine #50677: the "hidden" marking for classification mappings moves from the single mapping
# (classification_groups.hidden, #47172) up to the classification tree. A tree with
# hidden_mappings = TRUE means: its concepts do not show up on a content when the content only got
# them through a mapping — while a direct classification (and its broader ancestors) stays visible.
#
# The flag follows the `mappable` pattern (20250304132522): written on classification_tree_labels,
# carried to the read-only concept_schemes twin by the existing sync trigger functions. Deriving the
# tree flags from the per-mapping flags happens here, while classification_groups.hidden still
# exists — 20260728100001 drops it.
class AddHiddenMappingsToConceptSchemes < ActiveRecord::Migration[8.0]
  def up
    add_column :classification_tree_labels, :hidden_mappings, :boolean, default: false, null: false, if_not_exists: true
    add_column :concept_schemes, :hidden_mappings, :boolean, default: false, null: false, if_not_exists: true

    execute concept_scheme_trigger_functions(hidden_mappings: true)

    return unless column_exists?(:classification_groups, :hidden)

    execute <<~SQL.squish
      UPDATE classification_tree_labels ctl
      SET hidden_mappings = TRUE
      WHERE EXISTS (
          SELECT 1
          FROM classification_groups cg
            JOIN classification_trees ct ON ct.classification_alias_id = cg.classification_alias_id
            AND ct.deleted_at IS NULL
          WHERE ct.classification_tree_label_id = ctl.id
            AND cg.hidden
            AND cg.deleted_at IS NULL
        );
    SQL
  end

  def down
    execute concept_scheme_trigger_functions(hidden_mappings: false)

    remove_column :concept_schemes, :hidden_mappings, if_exists: true
    remove_column :classification_tree_labels, :hidden_mappings, if_exists: true
  end

  private

  def concept_scheme_trigger_functions(hidden_mappings:)
    column = hidden_mappings ? 'hidden_mappings,' : ''
    value = hidden_mappings ? 'nctl.hidden_mappings,' : ''
    update_set = hidden_mappings ? 'hidden_mappings = uctl.hidden_mappings,' : ''
    change_condition = hidden_mappings ? 'OR octl.hidden_mappings IS DISTINCT FROM nctl.hidden_mappings' : ''

    <<~SQL.squish
      CREATE OR REPLACE FUNCTION insert_concept_schemes_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_schemes(
          id,
          name,
          external_system_id,
          external_key,
          internal,
          mappable,
          #{column}
          visibility,
          change_behaviour,
          created_at,
          updated_at
        )
      SELECT nctl.id,
        nctl.name,
        nctl.external_source_id,
        nctl.external_key,
        nctl.internal,
        nctl.mappable,
        #{value}
        nctl.visibility,
        nctl.change_behaviour,
        nctl.created_at,
        nctl.updated_at
      FROM new_classification_tree_labels nctl ON CONFLICT DO NOTHING;

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION update_concept_schemes_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      UPDATE concept_schemes
      SET name = uctl.name,
        external_system_id = uctl.external_source_id,
        external_key = uctl.external_key,
        internal = uctl.internal,
        mappable = uctl.mappable,
        #{update_set}
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
            OR octl.external_key IS DISTINCT
          FROM nctl.external_key
            OR octl.internal IS DISTINCT
          FROM nctl.internal
            OR octl.mappable IS DISTINCT
          FROM nctl.mappable
            #{change_condition}
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
    SQL
  end
end

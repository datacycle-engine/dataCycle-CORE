# frozen_string_literal: true

class AddMappableForConceptSchemes < ActiveRecord::Migration[7.1]
  def up
    add_column :classification_tree_labels, :mappable, :boolean, default: true, null: false
    add_column :concept_schemes, :mappable, :boolean, default: true, null: false

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION insert_concept_schemes_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_schemes(
          id,
          name,
          external_system_id,
          external_key,
          internal,
          mappable,
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

  def down
    remove_column :classification_tree_label, :mappable
    remove_column :concept_schemes, :mappable

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION insert_concept_schemes_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_schemes(
          id,
          name,
          external_system_id,
          external_key,
          internal,
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

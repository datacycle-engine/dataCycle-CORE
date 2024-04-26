# frozen_string_literal: true

class UpdateTriggerForClassificationTreeLabelsWithExternalKey < ActiveRecord::Migration[6.1]
  def up
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

      CREATE OR REPLACE FUNCTION delete_concepts_to_histories_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$
      DECLARE insert_query TEXT;

      BEGIN
      SELECT 'INSERT INTO concept_histories (' || string_agg(column_name, ', ') || ') SELECT ' || string_agg('oc.' || column_name, ', ') || ' FROM old_concepts oc RETURNING id;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'concept_histories'
      AND column_name != 'deleted_at';

      EXECUTE insert_query;

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION delete_concept_schemes_to_histories_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$
      DECLARE insert_query TEXT;

      BEGIN
      SELECT 'INSERT INTO concept_scheme_histories (' || string_agg(column_name, ', ') || ') SELECT ' || string_agg('ocs.' || column_name, ', ') || ' FROM old_concept_schemes ocs RETURNING id;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'concept_scheme_histories'
      AND column_name != 'deleted_at';

      EXECUTE insert_query;

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION delete_concept_links_to_histories_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$
      DECLARE insert_query TEXT;

      BEGIN
      SELECT 'INSERT INTO concept_link_histories (' || string_agg(column_name, ', ') || ') SELECT ' || string_agg('ocl.' || column_name, ', ') || ' FROM old_concept_links ocl RETURNING id;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'concept_link_histories'
      AND column_name != 'deleted_at';

      EXECUTE insert_query;

      RETURN NULL;

      END;

      $$;
    SQL
  end

  def down
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

      CREATE OR REPLACE FUNCTION delete_concepts_to_histories_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_histories
      SELECT * FROM old_concepts;

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION delete_concept_schemes_to_histories_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_scheme_histories
      SELECT * FROM old_concept_schemes;

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION delete_concept_links_to_histories_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      INSERT INTO concept_link_histories
      SELECT * FROM old_concept_links;

      RETURN NULL;

      END;

      $$;
    SQL
  end
end

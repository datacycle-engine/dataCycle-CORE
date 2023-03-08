# frozen_string_literal: true

class AddFunctionForToHistory < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE thing_history_translations DROP COLUMN IF EXISTS history_valid;
      ALTER TABLE content_content_histories DROP COLUMN IF EXISTS history_valid;

      CREATE OR REPLACE FUNCTION to_thing_history_translation (
          content_id UUID,
          new_history_id UUID,
          current_locale VARCHAR,
          all_translations BOOLEAN DEFAULT FALSE
        ) RETURNS void LANGUAGE PLPGSQL AS $$
      DECLARE insert_query TEXT;

      BEGIN
      SELECT 'INSERT INTO thing_history_translations (thing_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM thing_translations t WHERE t.thing_id = ''' || content_id || '''::UUID AND (CASE WHEN ' || all_translations || '::BOOLEAN THEN t.locale IS NOT NULL ELSE t.locale = ''' || current_locale || '''::VARCHAR END);' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'thing_history_translations'
        AND column_name NOT IN ('id', 'thing_history_id');

      EXECUTE insert_query;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION to_classification_content_history (content_id UUID, new_history_id UUID) RETURNS void LANGUAGE PLPGSQL AS $$
      DECLARE insert_query TEXT;

      BEGIN
      SELECT 'INSERT INTO classification_content_histories (content_data_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM classification_contents t WHERE t.content_data_id = ''' || content_id || '''::UUID;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'classification_content_histories'
        AND column_name NOT IN ('id', 'content_data_history_id');

      EXECUTE insert_query;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION to_content_content_history (
          content_id UUID,
          new_history_id UUID,
          current_locale VARCHAR,
          all_translations BOOLEAN DEFAULT FALSE,
          deleted BOOLEAN DEFAULT FALSE
        ) RETURNS void LANGUAGE PLPGSQL AS $$
      DECLARE insert_linked_query TEXT;

      insert_embedded_query TEXT;

      BEGIN
      SELECT 'INSERT INTO content_content_histories (content_a_history_id, content_b_history_id, content_b_history_type, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, t.content_b_id, ''DataCycleCore::Thing'', ' || string_agg('t.' || column_name, ', ') || ' FROM content_contents t INNER JOIN things ON things.id = t.content_b_id WHERE t.content_a_id = ''' || content_id || '''::UUID AND things.content_type != ''embedded'';' INTO insert_linked_query
      FROM information_schema.columns
      WHERE table_name = 'content_content_histories'
        AND column_name NOT IN ('id', 'content_a_history_id', 'content_b_history_id', 'content_b_history_type');

      EXECUTE insert_linked_query;

      SELECT 'INSERT INTO content_content_histories (content_a_history_id, content_b_history_id, content_b_history_type, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, to_thing_history (t.content_b_id, ''' || current_locale || '''::VARCHAR, ' || all_translations || '::BOOLEAN, ' || deleted || '::BOOLEAN), ''DataCycleCore::Thing::History'', ' || string_agg('t.' || column_name, ', ') || ' FROM content_contents t INNER JOIN things ON things.id = t.content_b_id WHERE t.content_a_id = ''' || content_id || '''::UUID AND things.content_type = ''embedded'';' INTO insert_embedded_query
      FROM information_schema.columns
      WHERE table_name = 'content_content_histories'
        AND column_name NOT IN ('id', 'content_a_history_id', 'content_b_history_id', 'content_b_history_type');

      EXECUTE insert_embedded_query;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION to_schedule_history (content_id UUID, new_history_id UUID) RETURNS void LANGUAGE PLPGSQL AS $$
      DECLARE insert_query TEXT;

      BEGIN
      SELECT 'INSERT INTO schedule_histories (thing_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM schedules t WHERE t.thing_id = ''' || content_id || '''::UUID;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'schedule_histories'
        AND column_name NOT IN ('id', 'thing_history_id');

      EXECUTE insert_query;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION to_thing_history (
          content_id UUID,
          current_locale VARCHAR,
          all_translations BOOLEAN DEFAULT FALSE,
          deleted BOOLEAN DEFAULT FALSE
        ) RETURNS UUID LANGUAGE PLPGSQL AS $$
      DECLARE insert_query TEXT;

      new_history_id UUID;

      BEGIN
      SELECT 'INSERT INTO thing_histories (thing_id, deleted_at, ' || string_agg(column_name, ', ') || ') SELECT t.id, CASE WHEN t.deleted_at IS NOT NULL THEN t.deleted_at WHEN ' || deleted || '::BOOLEAN THEN transaction_timestamp() ELSE NULL END, ' || string_agg('t.' || column_name, ', ') || ' FROM things t WHERE t.id = ''' || content_id || '''::UUID LIMIT 1 RETURNING id;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'thing_histories'
        AND column_name NOT IN ('id', 'thing_id', 'deleted_at');

      EXECUTE insert_query INTO new_history_id;

      PERFORM to_thing_history_translation (
        content_id,
        new_history_id,
        current_locale,
        all_translations
      );

      PERFORM to_classification_content_history (content_id, new_history_id);

      PERFORM to_content_content_history (
        content_id,
        new_history_id,
        current_locale,
        all_translations,
        deleted
      );

      PERFORM to_schedule_history (content_id, new_history_id);

      RETURN new_history_id;

      END;

      $$;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS to_thing_history;
      DROP FUNCTION IF EXISTS to_schedule_history;
      DROP FUNCTION IF EXISTS to_content_content_history;
      DROP FUNCTION IF EXISTS to_classification_content_history;
      DROP FUNCTION IF EXISTS to_thing_history_translation;

      ALTER TABLE thing_history_translations ADD COLUMN history_valid tstzrange;
      ALTER TABLE content_content_histories ADD COLUMN history_valid tstzrange;
    SQL
  end
end

# frozen_string_literal: true

class UpdateToHistoryForNewTable < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION to_content_collection_link_history (content_id UUID, new_history_id UUID) RETURNS void LANGUAGE PLPGSQL AS $$
      DECLARE insert_query TEXT;

      BEGIN
      SELECT 'INSERT INTO content_collection_link_histories (thing_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM content_collection_links t WHERE t.thing_id = ''' || content_id || '''::UUID;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'content_collection_link_histories'
        AND column_name NOT IN ('id', 'thing_history_id', 'stored_filter_id', 'watch_list_id');

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

      PERFORM to_content_collection_link_history (content_id, new_history_id);

      RETURN new_history_id;

      END;

      $$;
    SQL
  end

  def down
    execute <<-SQL.squish
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

      DROP FUNCTION IF EXISTS to_content_collection_link_history (content_id UUID, new_history_id UUID);
    SQL
  end
end

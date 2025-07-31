# frozen_string_literal: true

class DoNothingIfThingHistoryCannotBeCreated < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.to_thing_history(
          content_id uuid,
          current_locale character varying,
          all_translations boolean DEFAULT false,
          deleted boolean DEFAULT false
        ) RETURNS uuid LANGUAGE plpgsql AS $$
      DECLARE insert_query TEXT;

      new_history_id UUID;

      BEGIN
      SELECT 'INSERT INTO thing_histories (thing_id, deleted_at, ' || string_agg(column_name, ', ') || ') SELECT t.id, CASE WHEN t.deleted_at IS NOT NULL THEN t.deleted_at WHEN ' || deleted || '::BOOLEAN THEN transaction_timestamp() ELSE NULL END, ' || string_agg('t.' || column_name, ', ') || ' FROM things t WHERE t.id = ''' || content_id || '''::UUID LIMIT 1 RETURNING id;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'thing_histories'
        AND column_name NOT IN ('id', 'thing_id', 'deleted_at');

      EXECUTE insert_query INTO new_history_id;

      IF new_history_id IS NULL THEN RETURN NULL;

      END IF;

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

      PERFORM to_geometry_history (content_id, new_history_id);

      RETURN new_history_id;

      END;

      $$;
    SQL
  end

  def down
  end
end

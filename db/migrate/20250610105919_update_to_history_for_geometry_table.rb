# frozen_string_literal: true

class UpdateToHistoryForGeometryTable < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.to_geometry_history (content_id UUID, new_history_id UUID) RETURNS void LANGUAGE PLPGSQL AS $$
      DECLARE insert_query TEXT;

      BEGIN
      SELECT 'INSERT INTO geometry_histories (thing_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM geometries t WHERE t.thing_id = ''' || content_id || '''::UUID;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'geometry_histories'
        AND column_name NOT IN ('id', 'thing_history_id', 'geom_simple');

      EXECUTE insert_query;

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.to_thing_history (
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

      PERFORM to_geometry_history (content_id, new_history_id);

      RETURN new_history_id;

      END;

      $$;
    SQL

    execute <<-SQL.squish
      CREATE OR REPLACE VIEW public.geometries_primary AS
      SELECT id,
        thing_id,
        priority,
        row_number() OVER (
          PARTITION BY thing_id
          ORDER BY priority
        ) = 1 AS is_primary
      FROM geometries;

      CREATE OR REPLACE FUNCTION public.update_geometries_is_primary(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN
      UPDATE geometries
      SET is_primary = geometries_primary.is_primary
      FROM geometries_primary
      WHERE geometries.id = geometries_primary.id
        AND geometries_primary.is_primary != geometries.is_primary
        AND geometries_primary.thing_id = ANY (thing_ids);

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.update_geometries_is_primary_trigger() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $BODY$ BEGIN PERFORM update_geometries_is_primary(ARRAY_AGG(thing_id))
      FROM (
          SELECT DISTINCT new_geometries.thing_id
          FROM new_geometries
            INNER JOIN old_geometries ON old_geometries.id = new_geometries.id
          WHERE new_geometries.priority IS DISTINCT
          FROM old_geometries.priority
        );

      RETURN NULL;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER update_geometries_priority_trigger
      AFTER
      UPDATE ON public.geometries REFERENCING NEW TABLE AS new_geometries OLD TABLE AS old_geometries FOR EACH STATEMENT EXECUTE FUNCTION public.update_geometries_is_primary_trigger();

      CREATE OR REPLACE FUNCTION public.update_geometries_is_primary_trigger2() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $BODY$ BEGIN PERFORM update_geometries_is_primary(ARRAY_AGG(thing_id))
      FROM (
          SELECT DISTINCT changed_geometries.thing_id
          FROM changed_geometries
        );

      RETURN NULL;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER insert_geometries_priority_trigger
      AFTER
      INSERT ON public.geometries REFERENCING NEW TABLE AS changed_geometries FOR EACH STATEMENT EXECUTE FUNCTION public.update_geometries_is_primary_trigger2();

      CREATE OR REPLACE TRIGGER delete_geometries_priority_trigger
      AFTER DELETE ON public.geometries REFERENCING OLD TABLE AS changed_geometries FOR EACH STATEMENT EXECUTE FUNCTION public.update_geometries_is_primary_trigger2();
    SQL

    execute <<-SQL.squish
      CREATE OR REPLACE VIEW public.geometries_changed_priorities AS
      SELECT geometries.id,
        (
          content_properties.property_definition->>'priority'
        )::integer AS priority,
        things.template_name,
        things.id AS thing_id
      FROM content_properties
        JOIN things ON things.template_name = content_properties.template_name
        JOIN geometries ON geometries.thing_id = things.id
        AND geometries.relation = content_properties.property_name
      WHERE (
          content_properties.property_definition->>'priority'
        )::integer != geometries.priority;

      CREATE OR REPLACE FUNCTION public.update_geo_priorities_by_template_name(template_names varchar []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(template_names, 1) > 0 THEN
      UPDATE geometries
      SET priority = geometries_changed_priorities.priority
      FROM geometries_changed_priorities
      WHERE geometries.id = geometries_changed_priorities.id
        AND geometries_changed_priorities.template_name = ANY (template_names);

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.update_thing_templates_geo_priorities_trigger() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $BODY$ BEGIN PERFORM update_geo_priorities_by_template_name(ARRAY_AGG(template_name))
      FROM (
          SELECT DISTINCT new_thing_templates.template_name
          FROM new_thing_templates
            INNER JOIN old_thing_templates ON old_thing_templates.template_name = new_thing_templates.template_name
          WHERE new_thing_templates.schema IS DISTINCT
          FROM old_thing_templates.schema
        );

      RETURN NULL;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER update_thing_templates_geo_priorities_trigger
      AFTER
      UPDATE ON public.thing_templates REFERENCING NEW TABLE AS new_thing_templates OLD TABLE AS old_thing_templates FOR EACH STATEMENT EXECUTE FUNCTION public.update_thing_templates_geo_priorities_trigger();

      CREATE OR REPLACE FUNCTION public.update_geo_priorities_by_thing_id(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN
      UPDATE geometries
      SET priority = geometries_changed_priorities.priority
      FROM geometries_changed_priorities
      WHERE geometries.id = geometries_changed_priorities.id
        AND geometries_changed_priorities.thing_id = ANY (thing_ids);

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.update_things_geo_priorities_trigger() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $BODY$ BEGIN PERFORM update_geo_priorities_by_thing_id(ARRAY_AGG(id))
      FROM (
          SELECT DISTINCT new_things.id
          FROM new_things
            INNER JOIN old_things ON old_things.id = new_things.id
          WHERE new_things.template_name IS DISTINCT
          FROM old_things.template_name
        );

      RETURN NULL;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER update_things_geo_priorities_trigger
      AFTER
      UPDATE ON public.things REFERENCING NEW TABLE AS new_things OLD TABLE AS old_things FOR EACH STATEMENT EXECUTE FUNCTION public.update_things_geo_priorities_trigger();
    SQL
  end

  def down
  end
end

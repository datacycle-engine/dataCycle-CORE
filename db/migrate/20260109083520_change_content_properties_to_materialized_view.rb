# frozen_string_literal: true

class ChangeContentPropertiesToMaterializedView < ActiveRecord::Migration[8.0]
  def up
    # API Name: Either in property_definition: api.v4.name; api.name; api.transformation.name; api.v4.transformation.name
    #           OR camelcased

    execute <<~SQL.squish
      DROP VIEW IF EXISTS content_property_dependencies;
      DROP VIEW IF EXISTS content_computed_properties;
      DROP VIEW IF EXISTS geometries_changed_priorities;
      DROP VIEW IF EXISTS content_properties;

      DROP MATERIALIZED VIEW IF EXISTS content_properties;

      CREATE MATERIALIZED VIEW content_properties AS
      SELECT thing_templates.template_name AS template_name,
        properties.key AS property_name,
        properties.value AS property_definition,
        COALESCE(
          properties.value->'api'->'v4'->'transformation'->>'name',
          properties.value->'api'->'v4'->>'name',
          properties.value->'api'->'transformation'->>'name',
          properties.value->'api'->>'name',
          lower(substring(properties.key,1,1)) || substring(replace(initcap(replace(properties.key, '_', ' ')), ' ', '') ,2)
        ) AS api_name
      FROM thing_templates
        CROSS JOIN LATERAL jsonb_each(thing_templates.schema->'properties'::text) properties(KEY, value);

      CREATE UNIQUE INDEX index_content_properties_unique_template_name_and_property_name
        ON public.content_properties (template_name, property_name);

      CREATE INDEX index_content_properties_api_name_and_property_name
        ON public.content_properties (api_name, property_name);


      CREATE OR REPLACE VIEW content_computed_properties AS
      SELECT content_properties.template_name,
        content_properties.property_name,
        split_part(parameters.value, '.', 1) AS compute_parameter_property_name
      FROM content_properties,
        LATERAL jsonb_array_elements_text(
          content_properties.property_definition->'compute'->'parameters'
        ) parameters(value)
      WHERE jsonb_typeof(
          content_properties.property_definition->'compute'->'parameters'
        ) = 'array';

      CREATE OR REPLACE VIEW content_property_dependencies AS
      SELECT t2.id AS content_id,
        t2.template_name,
        content_computed_properties.property_name,
        content_computed_properties.compute_parameter_property_name,
        things.id AS dependent_content_id,
        things.template_name AS dependent_content_template_name
      FROM things
        JOIN content_contents ON content_contents.content_b_id = things.id
        JOIN things t2 ON t2.id = content_contents.content_a_id
        JOIN content_computed_properties ON content_computed_properties.template_name = t2.template_name
        AND content_computed_properties.compute_parameter_property_name = content_contents.relation_a
      UNION
      SELECT t2.id AS content_id,
        t2.template_name,
        content_computed_properties.property_name,
        content_computed_properties.compute_parameter_property_name,
        things.id AS dependent_content_id,
        things.template_name AS dependent_content_template_name
      FROM things
        JOIN content_contents ON content_contents.content_a_id = things.id
        AND content_contents.relation_b IS NOT NULL
        JOIN things t2 ON t2.id = content_contents.content_b_id
        JOIN content_computed_properties ON content_computed_properties.template_name = t2.template_name
        AND content_computed_properties.compute_parameter_property_name = content_contents.relation_b;
    SQL

    execute <<~SQL.squish
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
    execute <<~SQL
      DROP MATERIALIZED VIEW IF EXISTS content_properties;
    SQL

    execute <<~SQL
      DROP VIEW IF EXISTS content_properties;

      CREATE OR REPLACE VIEW content_properties AS
      SELECT thing_templates.template_name AS template_name,
        properties.key AS property_name,
        properties.value AS property_definition
      FROM thing_templates
        CROSS JOIN LATERAL jsonb_each(thing_templates.schema->'properties'::text) properties(KEY, value);
    SQL
  end
end

# frozen_string_literal: true

class AddColumnsToContentProperties < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      DROP VIEW IF EXISTS content_property_dependencies;
      DROP VIEW IF EXISTS content_computed_properties;
      DROP VIEW IF EXISTS geometries_changed_priorities;

      DROP MATERIALIZED VIEW IF EXISTS content_properties;

      CREATE MATERIALIZED VIEW content_properties AS
      WITH recursive properties(
        template_name,
        property_name,
        api_name,
        property_type,
        advanced_search,
        property_definition
      ) AS (
        SELECT thing_templates.template_name AS template_name,
          properties.key AS property_name,
          COALESCE(
            properties.value->'api'->'v4'->'transformation'->>'name',
            properties.value->'api'->'v4'->>'name',
            properties.value->'api'->'transformation'->>'name',
            properties.value->'api'->>'name',
            lower(substring(properties.key, 1, 1)) || substring(
              REPLACE(
                initcap(REPLACE(properties.key, '_', ' ')),
                ' ',
                ''
              ),
              2
            )
          ) AS api_name,
          properties.value->>'type' AS property_type,
          (properties.value->>'advanced_search')::bool AS advanced_search,
          properties.value AS property_definition
        FROM thing_templates
          CROSS JOIN LATERAL jsonb_each(thing_templates.schema->'properties'::text) properties(KEY, value)
        UNION
        SELECT properties.template_name AS template_name,
          CONCAT_WS('.', properties.property_name, p2.key) AS property_name,
          CONCAT_WS(
            '.',
            properties.api_name,
            COALESCE(
              p2.value->'api'->'v4'->'transformation'->>'name',
              p2.value->'api'->'v4'->>'name',
              p2.value->'api'->'transformation'->>'name',
              p2.value->'api'->>'name',
              lower(substring(p2.key, 1, 1)) || substring(
                REPLACE(
                  initcap(REPLACE(p2.key, '_', ' ')),
                  ' ',
                  ''
                ),
                2
              )
            )
          ) AS api_name,
          p2.value->>'type' AS property_type,
          (p2.value->>'advanced_search')::bool AS advanced_search,
          p2.value AS property_definition
        FROM properties
          CROSS JOIN LATERAL jsonb_each(
            properties.property_definition->'properties'::text
          ) p2(KEY, value)
        WHERE properties.property_definition->'properties' IS NOT NULL
      )
      SELECT *
      FROM properties;

      CREATE UNIQUE INDEX index_cp_unique_tn_pn ON public.content_properties (template_name, property_name);

      CREATE INDEX index_cp_an_pn ON public.content_properties (api_name, property_name);
      CREATE INDEX index_cp_an_as_pn ON public.content_properties (api_name, advanced_search, property_name);

      CREATE INDEX index_cp_an_pt_pn ON public.content_properties (api_name, property_type, property_name);
      CREATE INDEX index_cp_an_as_pt_pn ON public.content_properties (api_name, advanced_search, property_type, property_name);

      CREATE INDEX index_cp_pn_pt ON public.content_properties (property_name, property_type);
      CREATE INDEX index_cp_pn_as_pt ON public.content_properties (property_name, advanced_search, property_type);

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
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP VIEW IF EXISTS content_property_dependencies;
      DROP VIEW IF EXISTS content_computed_properties;
      DROP VIEW IF EXISTS geometries_changed_priorities;

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
    SQL
  end
end

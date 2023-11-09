# frozen_string_literal: true

class RefactorSomeViewsForProperties < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP VIEW IF EXISTS content_property_dependencies;
      DROP VIEW IF EXISTS content_computed_properties;
      DROP VIEW IF EXISTS content_properties;

      CREATE OR REPLACE VIEW content_properties AS
      SELECT thing_templates.template_name AS template_name,
        properties.key AS property_name,
        properties.value AS property_definition
      FROM thing_templates
        CROSS JOIN LATERAL jsonb_each(thing_templates.schema->'properties'::text) properties(KEY, value);

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
  end

  def down
    execute <<-SQL.squish
      DROP VIEW IF EXISTS content_property_dependencies;
      DROP VIEW IF EXISTS content_computed_properties;
      DROP VIEW IF EXISTS content_properties;

      CREATE OR REPLACE VIEW content_properties AS
      SELECT things.id AS content_id,
        things.template_name AS content_template_name,
        properties.key AS property_name,
        properties.value AS property_definition
      FROM things
        JOIN thing_templates ON thing_templates.template_name = things.template_name
        CROSS JOIN LATERAL jsonb_each(thing_templates.schema->'properties'::text) properties(KEY, value);

      CREATE OR REPLACE VIEW content_computed_properties AS
      SELECT content_properties.content_id,
        content_properties.content_template_name,
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
      SELECT content_computed_properties.content_id,
        content_computed_properties.content_template_name,
        content_computed_properties.property_name,
        content_computed_properties.compute_parameter_property_name,
        things.id AS dependent_content_id,
        things.template_name AS dependent_content_template_name
      FROM things
        JOIN content_contents ON content_contents.content_b_id = things.id
        JOIN content_computed_properties ON content_computed_properties.content_id = content_contents.content_a_id
        AND content_computed_properties.compute_parameter_property_name = content_contents.relation_a;
    SQL
  end
end

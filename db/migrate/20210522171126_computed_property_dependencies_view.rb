# frozen_string_literal: true

class ComputedPropertyDependenciesView < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      DROP VIEW IF EXISTS "content_property_dependencies";
      DROP VIEW IF EXISTS "content_computed_properties";
      DROP VIEW IF EXISTS "content_properties";

      CREATE VIEW "content_properties" AS
      SELECT
      	things.id "content_id",
      	things.template_name "content_template_name",
      	properties.key "property_name",
      	properties.value "property_definition"
      FROM things, jsonb_each(things.schema -> 'properties') "properties";

      CREATE VIEW "content_computed_properties" AS
      SELECT
      	content_properties.content_id,
      	content_properties.content_template_name,
      	content_properties.property_name,
      	parameters.key "compute_parameter_order",
      	parameters.value "compute_parameter_definition",
      	COALESCE(parameters.value ->> 'name', parameters.value #>> '{}') "compute_parameter_property_name"
      FROM content_properties, jsonb_each(property_definition -> 'compute' -> 'parameters') "parameters"
      WHERE property_definition ->> 'type' = 'computed';

      CREATE VIEW "content_property_dependencies" AS
      SELECT
      	content_computed_properties.content_id,
      	content_computed_properties.content_template_name,
      	content_computed_properties.property_name,
      	things.id "dependent_content_id",
      	things.template_name "dependent_content_template_name"
      FROM things
      JOIN content_contents ON content_contents.content_b_id = things.id
      JOIN content_computed_properties ON
      	content_computed_properties.content_id = content_contents.content_a_id AND
      	content_computed_properties.compute_parameter_property_name = content_contents.relation_a;
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP VIEW "content_property_dependencies";
      DROP VIEW "content_computed_properties";
      DROP VIEW "content_properties";
    SQL
  end
end

# frozen_string_literal: true

class UpdateViewsForContentPropertyDependencies < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
      DROP VIEW IF EXISTS "content_property_dependencies";

      DROP VIEW IF EXISTS "content_computed_properties";

      CREATE VIEW "content_computed_properties" AS
      SELECT
        content_properties.content_id,
        content_properties.content_template_name,
        content_properties.property_name,
        split_part(parameters, '.', '1') "compute_parameter_property_name"
      FROM
        content_properties,
        jsonb_array_elements_text(property_definition -> 'compute' -> 'parameters') "parameters"
      WHERE
        property_definition ? 'compute';

      CREATE VIEW "content_property_dependencies" AS
      SELECT
        content_computed_properties.content_id,
        content_computed_properties.content_template_name,
        content_computed_properties.property_name,
        content_computed_properties.compute_parameter_property_name,
        things.id "dependent_content_id",
        things.template_name "dependent_content_template_name"
      FROM
        things
        JOIN content_contents ON content_contents.content_b_id = things.id
        JOIN content_computed_properties ON content_computed_properties.content_id = content_contents.content_a_id
          AND content_computed_properties.compute_parameter_property_name = content_contents.relation_a;
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP VIEW IF EXISTS "content_property_dependencies";
      DROP VIEW "content_computed_properties";
    SQL
  end
end

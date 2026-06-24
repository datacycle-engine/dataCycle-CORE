# frozen_string_literal: true

class UpdateViewsForContentContentLinks < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      DROP VIEW IF EXISTS content_property_dependencies;

      CREATE OR REPLACE VIEW content_property_dependencies AS
      SELECT t2.id AS content_id,
        t2.template_name,
        content_computed_properties.property_name,
        content_computed_properties.compute_parameter_property_name,
        things.id AS dependent_content_id,
        things.template_name AS dependent_content_template_name
      FROM things
        JOIN content_content_links ccl ON ccl.content_b_id = things.id
        JOIN things t2 ON t2.id = ccl.content_a_id
        JOIN content_computed_properties ON content_computed_properties.template_name::text = t2.template_name::text
        AND content_computed_properties.compute_parameter_property_name = ccl.relation::text
      WHERE ccl.relation IS NOT NULL;
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP VIEW IF EXISTS content_property_dependencies;

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
end

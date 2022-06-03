# frozen_string_literal: true

class AddParameterNameToViewForContentPropertyDependencies < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
      DROP VIEW IF EXISTS "content_property_dependencies";

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
    SQL
  end
end

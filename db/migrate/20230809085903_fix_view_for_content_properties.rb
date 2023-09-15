# frozen_string_literal: true

class FixViewForContentProperties < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE VIEW public.content_computed_properties AS
      SELECT content_properties.content_id,
        content_properties.content_template_name,
        content_properties.property_name,
        split_part(parameters.value, '.'::text, 1) AS compute_parameter_property_name
      FROM content_properties,
        LATERAL jsonb_array_elements_text(
          (
            (
              content_properties.property_definition->'compute'::text
            )->'parameters'::text
          )
        ) parameters(value)
      WHERE jsonb_typeof(
          content_properties.property_definition->'compute'->'parameters'
        ) = 'array';
    SQL
  end

  def down
  end
end

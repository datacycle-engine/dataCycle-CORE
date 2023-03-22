# frozen_string_literal: true

class FixComputedSchemaTypesAgain < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION compute_thing_schema_types (
          schema_types jsonb,
          template_name varchar DEFAULT NULL
        ) RETURNS varchar [] LANGUAGE PLPGSQL AS $$
      DECLARE agg_schema_types varchar [];

      BEGIN WITH RECURSIVE schema_ancestors AS (
        SELECT t.ancestors,
          t.idx
        FROM jsonb_array_elements(schema_types) WITH ordinality AS t(ancestors, idx)
        WHERE t.ancestors IS NOT NULL
        UNION ALL
        SELECT t.ancestors,
          schema_ancestors.idx + t.idx * 100
        FROM schema_ancestors,
          jsonb_array_elements(schema_ancestors.ancestors) WITH ordinality AS t(ancestors, idx)
        WHERE jsonb_typeof(schema_ancestors.ancestors) = 'array'
      ),
      collected_schema_types AS (
        SELECT (schema_ancestors.ancestors->>0)::varchar AS ancestors,
          max(schema_ancestors.idx) AS idx
        FROM schema_ancestors
        WHERE jsonb_typeof(schema_ancestors.ancestors) != 'array'
        GROUP BY schema_ancestors.ancestors
      )
      SELECT array_agg(
          ancestors
          ORDER BY collected_schema_types.idx
        )::varchar [] INTO agg_schema_types
      FROM collected_schema_types;

      IF array_length(agg_schema_types, 1) > 0 THEN agg_schema_types := agg_schema_types || ('dcls:' || template_name)::varchar;
      END IF;

      RETURN agg_schema_types;

      END;

      $$;
    SQL
  end

  def down
  end
end

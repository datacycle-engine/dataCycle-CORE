# frozen_string_literal: true

class AddSchemaTypesColumnToThings < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE things ADD COLUMN computed_schema_types VARCHAR[];
      CREATE INDEX things_computed_schema_types_idx ON things USING gin (computed_schema_types);

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
        UNION
        SELECT t.ancestors,
          t.idx
        FROM schema_ancestors,
          jsonb_array_elements(schema_ancestors.ancestors) WITH ordinality AS t(ancestors, idx)
        WHERE jsonb_typeof(schema_ancestors.ancestors) = 'array'
      )
      SELECT array_agg(
          (schema_ancestors.ancestors->>0)::varchar
          ORDER BY schema_ancestors.idx
        )::varchar [] INTO agg_schema_types AS ancestors
      FROM schema_ancestors
      WHERE jsonb_typeof(schema_ancestors.ancestors) != 'array';

      IF template_name IS NOT NULL
      AND array_length(agg_schema_types, 1) > 0
      AND agg_schema_types [array_length(agg_schema_types, 1)] != template_name THEN agg_schema_types := agg_schema_types || ('dcls:' || template_name)::varchar;

      END IF;

      RETURN agg_schema_types;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_thing_schema_types () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN
        SELECT compute_thing_schema_types(NEW."schema"->'schema_ancestors', NEW.template_name) INTO NEW.computed_schema_types;

      RETURN NEW;

      END;

      $$;

      CREATE TRIGGER insert_thing_schema_types BEFORE
      INSERT ON things FOR EACH ROW EXECUTE FUNCTION generate_thing_schema_types ();

      CREATE TRIGGER update_thing_schema_types BEFORE
      UPDATE of template_name,
        "schema" ON things FOR EACH ROW
        WHEN (
          OLD.template_name IS DISTINCT
          FROM NEW.template_name
            OR OLD."schema" IS DISTINCT
          FROM NEW."schema"
        ) EXECUTE FUNCTION generate_thing_schema_types ();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS insert_thing_schema_types ON things;
      DROP TRIGGER IF EXISTS update_thing_schema_types ON things;

      DROP FUNCTION IF EXISTS generate_thing_schema_types;
      DROP FUNCTION IF EXISTS compute_thing_schema_types;

      ALTER TABLE things DROP COLUMN computed_schema_types;
    SQL
  end
end

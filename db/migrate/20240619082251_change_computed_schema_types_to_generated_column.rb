# frozen_string_literal: true

class ChangeComputedSchemaTypesToGeneratedColumn < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION compute_thing_schema_types(
          schema_types jsonb,
          template_name character varying DEFAULT NULL::character varying
        ) RETURNS character varying [] LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE AS $BODY$
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

      $BODY$;

      ALTER TABLE IF EXISTS thing_templates DROP COLUMN IF EXISTS computed_schema_types;

      ALTER TABLE thing_templates
      ADD COLUMN computed_schema_types character varying[] GENERATED ALWAYS AS (
          compute_thing_schema_types(schema->'schema_ancestors', template_name)
        ) STORED;

      DROP TRIGGER IF EXISTS insert_thing_templates_schema_types ON thing_templates;
      DROP TRIGGER IF EXISTS update_thing_templates_schema_types ON thing_templates;

      DROP FUNCTION IF EXISTS generate_thing_schema_types();
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE IF EXISTS thing_templates DROP COLUMN IF EXISTS computed_schema_types;

      ALTER TABLE IF EXISTS thing_templates
      ADD COLUMN computed_schema_types character varying [];

      CREATE OR REPLACE FUNCTION compute_thing_schema_types(
          schema_types jsonb,
          template_name character varying DEFAULT NULL::character varying
        ) RETURNS character varying [] LANGUAGE 'plpgsql' AS $BODY$
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

      $BODY$;

      CREATE OR REPLACE FUNCTION generate_thing_schema_types() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $BODY$ BEGIN
      SELECT compute_thing_schema_types(
          NEW."schema"->'schema_ancestors',
          NEW.template_name
        ) INTO NEW.computed_schema_types;

      RETURN NEW;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER insert_thing_templates_schema_types BEFORE
      INSERT ON thing_templates FOR EACH ROW EXECUTE FUNCTION generate_thing_schema_types();

      CREATE OR REPLACE TRIGGER update_thing_templates_schema_types BEFORE
      UPDATE OF template_name,
        schema ON thing_templates FOR EACH ROW
        WHEN (
          old.template_name::text IS DISTINCT
          FROM new.template_name::text
            OR old.schema IS DISTINCT
          FROM new.schema
        ) EXECUTE FUNCTION generate_thing_schema_types();

      UPDATE thing_templates SET computed_schema_types = compute_thing_schema_types(schema->'schema_ancestors', template_name);
    SQL
  end
end
